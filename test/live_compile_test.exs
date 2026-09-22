defmodule LiveCompileTest do
  use ExUnit.Case
  import LiveCompile
  doctest LiveCompile

  test "e/1 compiles and evaluates an expression" do
    assert e(Enum.map([1, 2, 3], &(&1 * 2))) == [2, 4, 6]
  end
end
