defmodule LiveCompileTest do
  use ExUnit.Case
  import LiveCompile
  doctest LiveCompile

  test "e/1 compiles and evaluates an expression" do
    assert e(Enum.map([1, 2, 3], &(&1 * 2))) == [2, 4, 6]
  end

  test "multiple blocks in one evaluated cell preserve caller variables" do
    {result, _binding} =
      Code.eval_string("""
      import LiveCompile
      values = [1, 2, 3]
      res = 10
      first = e do
        Enum.map(values, &(&1 * 2))
      end
      second = e do
        Enum.map(first, &(&1 + res))
      end
      {first, second, res}
      """)

    assert result == {[2, 4, 6], [12, 14, 16], 10}
  end

  test "multiple pipeline helpers in one evaluated cell" do
    {result, _binding} =
      Code.eval_string("""
      import LiveCompile
      [1, 2, 3]
      |> e(Enum.map(&(&1 * 2)))
      ~> Enum.map(&(&1 + 1))
      """)

    assert result == [3, 5, 7]
  end
end
