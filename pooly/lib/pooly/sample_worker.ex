defmodule SampleWorker do
  use GenServer
  require Logger

  def work_for(pid, duration) do
    GenServer.cast(pid, {:work_for, duration})
  end

  def start_link(_) do
    Logger.info("Starting SampleWorker...")
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def stop(pid) do
    Logger.info("Stopping SampleWorker...")
    GenServer.call(pid, :stop)
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast({:work_for, duration}, state) do
    :timer.sleep(duration)
    {:stop, :normal, state}
  end
end

