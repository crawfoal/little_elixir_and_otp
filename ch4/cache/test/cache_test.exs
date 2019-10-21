defmodule CacheTest do
  use ExUnit.Case
  doctest Cache

  test "write/3 and read/2" do
    {:ok, pid} = Cache.start_link()

    Cache.write(pid, :stooges, ["Larry", "Curly", "Moe"])

    assert Cache.read(pid, :stooges) == ["Larry", "Curly", "Moe"]
  end

  test "delete/2" do
    {:ok, pid} = Cache.start_link()
    Cache.write(pid, :stooges, ["Larry", "Curly", "Moe"])

    Cache.delete(pid, :stooges)

    assert Cache.read(pid, :stooges) == nil
  end

  test "clear/1" do
    {:ok, pid} = Cache.start_link()
    Cache.write(pid, :stooges, ["Larry", "Curly", "Moe"])

    Cache.clear(pid)

    assert Cache.read(pid, :stooges) == nil
  end

  test "exists?/2" do
    {:ok, pid} = Cache.start_link()
    Cache.write(pid, :stooges, ["Larry", "Curly", "Moe"])

    assert Cache.exists?(pid, :stooges)
  end
end

