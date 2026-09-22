defmodule LiveCompile do
  @moduledoc """
  Lightning-fast ad-hoc data transformations in Livebook and IEx using dynamic
  JIT compilation.

  Interactive environments like Livebook and the IEx shell evaluate expressions
  step-by-step using an interpreter (`:erl_eval`). When executing intense
  functions over thousands of items inside `Enum` loops, this evaluation
  becomes a bottleneck.

  `LiveCompile` solves this by capturing your pipeline's Abstract Syntax Tree
  (AST), automatically injecting all local variables available in your current
  shell scope (`Macro.Env.vars/1`), and compiling the block into a native
  Erlang VM (`BEAM`) module in memory.

  The dynamic compilation overhead is typically around `10 ms`, but execution
  runs at full production-grade compiled speed, leading to **10x to 100x
  performance improvements**.

  It provides the `e/1` and `e/2` macros and the `~>` operator for convenient use.
  """

  @doc """
  Compiles a block of code or an inline expression into a single native module.

  Can be used as a multi-line `do...end` block or as a single expression.

  ## Examples

  Using a `do...end` block (recommended for full pipelines):

      import LiveCompile

      diffs = e do
        msgs
        |> Enum.filter(&Map.has_key?(&1.value, :end))
        |> Enum.map(&%{ts: &1.timestamp, diff: &1.value.end - &1.timestamp})
      end

  Using a single inline expression:

      import LiveCompile

      e(Enum.map(1..1_000_000, &(&1 * 2)))
  """
  defmacro e(block) do
    block =
      case block do
        [do: block] -> block
        block -> block
      end

    module_name = Module.concat(__MODULE__, "CompiledBlock_#{uid(__CALLER__)}")
    caller_vars = Macro.Env.vars(__CALLER__)

    bindings =
      Enum.map(caller_vars, fn {name, context} ->
        {name, [generated: true], context}
      end)

    caller_location = Macro.Env.location(__CALLER__)

    module_contents =
      quote do
        def run(unquote_splicing(bindings)) do
          unquote(block)
        end
      end

    line = __CALLER__.line

    quote do
      {compilation_time_us, {:module, compiled_module, _, _}} =
        :timer.tc(fn ->
          Module.create(
            unquote(module_name),
            unquote(Macro.escape(module_contents)),
            unquote(Macro.escape(caller_location))
          )
        end)

      IO.puts("#{unquote(line)}:compiled in #{Float.round(compilation_time_us / 1000, 2)} ms")
      res = compiled_module.run(unquote_splicing(bindings))
      :code.purge(unquote(module_name))
      :code.delete(unquote(module_name))
      res
    end
  end

  @doc """
  A surgical pipeline operator that isolates and compiles exclusively the
  right-hand side expression.

  The left-hand side expression evaluates normally (interpreted), its result is
  assigned to a temporary variable, and then injected into the compiled
  right-hand expression. This ensures only the chosen bottleneck row gets
  compiled.

  ## Examples

      import LiveCompile

      diffs =
        msgs
        |> Enum.filter(& &1.timestamp > 1000)   # Interpreted
        ~> Enum.map(& %{&1 | value: :done})     # COMPILED
        |> Enum.take(5)                         # Interpreted
  """
  defmacro left ~> right do
    name = String.to_atom("pipe_val_#{uid(__CALLER__)}")
    var = {name, [generated: true], nil}

    quote do
      unquote(var) = unquote(left)
      e(unquote(var) |> unquote(right))
    end
  end

  @doc """
  An inline alternative to the `~>` operator designed to fit natively into standard pipelines.

  It behaves identically to `~>` by delegating the left-hand data into the right-hand transformation.

  ## Examples

      import LiveCompile

      diffs =
        msgs
        |> e(Enum.filter(&Map.has_key?(&1.value, :end)))
        |> Enum.take(5)
  """
  defmacro e(left, right) do
    quote do
      unquote(left) ~> unquote(right)
    end
  end

  defp uid(caller) do
    line = caller.line
    file = caller.file |> String.replace(~r"[.#/]+", "_")
    "#{file}:#{line}"
  end
end
