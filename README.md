# LiveCompile

`LiveCompile` provides lightning-fast ad-hoc data transformations in
**Livebook** and **IEx** by leveraging dynamic JIT (Just-In-Time) compilation
directly into the Erlang VM (BEAM) memory.

## The Problem

When working with larger datasets in interactive environments like Livebook or
the IEx shell, data manipulation pipelines often become incredibly slow. For
example, running `Enum.map/2` with an anonymous function that does non-trivial
transformation can take seconds or even minutes.

This happens because **Livebook and IEx evaluate expressions step-by-step using
an interpreter (`:erl_eval`)**. Anonymous lambdas declared inside cells are
interpreted on every single iteration instead of being compiled into bytecode,
bypassing BEAM's powerful compiler optimizations including JIT compilation.

## The Solution

`LiveCompile` solves this by capturing your pipeline's Abstract Syntax Tree
(AST) using macros, automatically grabbing all available variables from the
caller's environment (`Macro.Env.vars/1`), and instantly compiling the entire
block as a native module using `Module.create/3`.

The compilation overhead is typically **around 10 millisecond**, but the
execution runs at **full production-grade compiled speed**, easily resulting in
**10x to 100x performance improvements** during interactive data analysis.

## Installation

Add `live_compile` to your dependencies in Livebook's setup cell or your `mix.exs`:

```elixir
Mix.install([
  {:live_compile, "~> 0.1.0"}
])
```

*Note: Requires Elixir `1.15+` as it relies on `Macro.Env.vars/1`.*

## Usage

Import `LiveCompile` at the beginning of your data analysis cell to unlock
three flexible ways of boosting your pipeline performance using the **`e`**
macro or surgical **~>** pipe operator.

### 1. Block Macro (`e do ... end`)

Wrap a full multi-line data pipeline. The entire block gets compiled into a
single temporary native module. This offers the best performance since BEAM can
optimize inter-function transitions as a single unit.

```elixir
import LiveCompile

diffs = e do
  msgs
  |> Enum.filter(&Map.has_key?(&1.value, :end))
  |> Enum.map(&%{ts: &1.timestamp, diff: &1.value.end - &1.timestamp})
end
```

### 2. Surgical Pipeline Operator (`~>`)

If you only want to compile a single heavy transformation line within a
standard Elixir pipeline, swap `|>` for `~>`. Everything before it remains
interpreted, but the right-hand expression gets isolated and compiled natively.

```elixir
import LiveCompile

diffs =
  msgs
  |> Enum.filter(& &1.timestamp > 1000)   # Interpreted
  ~> Enum.map(& %{&1 | value: :done})     # COMPILED
  |> Enum.take(5)                         # Interpreted
```

*Tip: You can chain multiple `~>` operators sequentially, or wrap a
sub-pipeline in parentheses `~> (A |> B)` to group them into a single compiled
module.*

### 3. Inline Macro Helper (`|> e(...)`)

An alternative syntax to the `~>` operator designed to fit natively into
standard pipeline visual styles. It acts identically to the operator under the
hood.

```elixir
import LiveCompile

diffs =
  msgs
  |> e(Enum.filter(&Map.has_key?(&1.value, :end)))
  |> Enum.take(5)
```

## Micro-benchmarking Included

Every time a `LiveCompile` macro executes, it measures the exact time spent on
module generation. It automatically prints a clear blueprint right under your
Livebook cell showing the line number and compile time:

```text
5:compiled in 8.42 ms
```

This allows you to verify instantly whether the compilation JIT step was worth
it (which it always is for larger collections!).

## How Error Reporting and Closures Work

- **Automatic Closures:** You do not need to manually pass variable bindings.
The macro safely inspects your local scope and brings external datasets
(`msgs`, configuration flags, keys, etc.) right inside the isolated compiled
module.
- **Accurate Stacktraces:** Thanks to `Macro.Env.location/1` enforcement during
module spawning, any runtime exceptions or crashes (e.g. failed pattern
matches) will correctly highlight the exact line inside your original Livebook
cell, rather than blaming an anonymous background module.

## License

`LiveCompile` is released under the MIT License.
