defmodule Ex3 do
  def t(list) do
    list
    |> List.flatten()
    |> Enum.map(fn x -> x * x end)
    |> Enum.sort()
    |> Enum.reverse()
  end

  def t_ugly(list) do
    Enum.reverse(Enum.sort(Enum.map(List.flatten(list), fn x -> x * x end)))
  end
end

ExUnit.start()

defmodule Ex3Test do
  use ExUnit.Case, async: true

  test "t/1" do
    assert Ex3.t([1, [[2], 3]]) == [9, 4, 1]
  end

  test "t_ugly/1" do
    assert Ex3.t_ugly([1, [[2], 3]]) == [9, 4, 1]
  end
end

