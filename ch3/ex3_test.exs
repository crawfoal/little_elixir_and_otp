defmodule Ex3 do

  def ping do
    receive do
      {pid, :ping} ->
        send(pid, :pong)
        ping()
      _ -> ping()
    end
  end

  def pong do
    receive do
      {pid, :pong} ->
        send(pid, :ping)
        pong()
      _ -> pong()
    end
  end
end

ExUnit.start()

defmodule Ex3Test do
  use ExUnit.Case, async: true

  test "ping" do
    pid = spawn(Ex3, :ping, [])

    send(pid, {self(), :ping})

    assert_receive :pong
  end

  test "pong" do
    pid = spawn(Ex3, :pong, [])

    send(pid, {self(), :pong})

    assert_receive :ping
  end
end

