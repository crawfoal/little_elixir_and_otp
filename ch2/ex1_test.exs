defmodule Ex1 do
  def sum([]), do: 0
  def sum([head | tail]), do: head + sum(tail)
end

ExUnit.start()

defmodule Ex1Test do
  use ExUnit.Case, async: true

  test "sum/1 for empty list" do
    assert Ex1.sum([]) == 0
  end

  test "sum/1 for single element list" do
    assert Ex1.sum([3]) == 3
  end

  test "sum/1 for list with two elements" do
    assert Ex1.sum([3, 2]) == 5
  end
end

