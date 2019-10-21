defmodule MetexTest do
  use ExUnit.Case
  doctest Metex

  alias Metex.Worker

  test "get_temperature/1" do
    {:ok, pid} = Worker.start_link

    temp = Worker.get_temperature(pid, "Boulder")

    # I guess we don't care about the actual format, just that it's a
    # temperature ¯\_(ツ)_/¯
    assert String.match?(temp, ~r/\d+\.\d°C/)
  end

  test "get_stats/1" do
    {:ok, pid} = Worker.start_link
    Worker.get_temperature(pid, "Boulder")
    Worker.get_temperature(pid, "Boulder")
    Worker.get_temperature(pid, "Chicago")

    stats = Worker.get_stats(pid)

    assert stats == %{"Boulder" => 2, "Chicago" => 1}
  end

  test "reset_stats/0" do
    {:ok, pid} = Worker.start_link
    Worker.get_temperature(pid, "Boulder")
    Worker.get_temperature(pid, "Boulder")
    Worker.get_temperature(pid, "Chicago")

    Worker.reset_stats(pid)

    assert Worker.get_stats(pid) == %{}
  end

  test "stop/1" do
    {:ok, pid} = Worker.start_link

    Worker.stop(pid)

    # Sucky and possibly flaky, I know. I considered sending the process a call
    # message, but although that would work for most casts, it doesn't here
    # because it is a shutdown. I also attempted sending a message from
    # `terminate/2` and waiting for that message to arrive before testing, but
    # that doesn't work either because the shutdown isn't complete until after
    # `terminate/2` ends. I think this is just a weird thing to test, maybe.
    Process.sleep(60)
    refute Process.alive?(pid)
  end
end
