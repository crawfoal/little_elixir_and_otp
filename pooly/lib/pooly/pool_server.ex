defmodule Pooly.PoolServer do
  use GenServer
  import Supervisor.Spec
  require Logger

  defmodule State do
    defstruct pool_sup: nil, worker_sup: nil, monitors: nil, size: nil,
      workers: nil, name: nil, mfa: nil, overflow: 0, max_overflow: nil,
      waiting: nil
  end

  def start_link(pool_sup, pool_config) do
    GenServer.start_link(
      __MODULE__,
      [pool_sup, pool_config],
      name: name(pool_config[:name])
    )
  end

  def checkout(pool_name, block, timeout) do
    GenServer.call(name(pool_name), {:checkout, block}, timeout)
  end

  def checkin(pool_name, worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  #############
  # Callbacks #
  #############

  def init([pool_sup, pool_config]) when is_pid(pool_sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    waiting = :queue.new
    state = %State{pool_sup: pool_sup, monitors: monitors, waiting: waiting}
    init(pool_config, state)
  end

  def init([{:max_overflow, max_overflow} | rest], state) do
    init(rest, %{ state | max_overflow: max_overflow })
  end
  def init([{:name, name} | rest], state) do
    Logger.info("Initializing pool server for #{name}.")
    init(rest, %{ state | name: name })
  end
  def init([{:mfa, mfa} | rest], state) do
    init(rest, %{ state | mfa: mfa })
  end
  def init([{:size, size} | rest], state) do
    init(rest, %{ state | size: size })
  end
  def init([ _ | rest ], state) do
    init(rest, state)
  end
  def init([], state) do
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  def handle_call({:checkout, block}, {from_pid, _ref} = from, state) do
    %{max_overflow: max_overflow,
      monitors: monitors,
      overflow: overflow,
      waiting: waiting,
      workers: workers,
      worker_sup: worker_sup} = state

    case workers do
      [worker | rest] ->
        Logger.info("Checking out standard worker.")
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}

      [] when max_overflow > 0 and overflow < max_overflow ->
        Logger.info("Creating and checking out overflow worker.")
        {worker, ref} = {new_worker(worker_sup), Process.monitor(from_pid)}
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | overflow: overflow + 1}}

      [] when block == true ->
        Logger.info("Blocking consumer process #{inspect from_pid} to wait for worker.")
        ref = Process.monitor(from_pid)
        waiting = :queue.in({from, ref}, waiting)
        {:noreply, %{ state | waiting: waiting }, :infinity}

      [] ->
        Logger.info("Failed to checkout worker for #{inspect from_pid}; all worker taken.")
        {:reply, :full, state}
    end
  end
  def handle_call(:status, _from, state) do
    %{
      monitors: monitors,
      waiting: waiting,
      workers: workers
    } = state

    status = %{
      state: state_name(state),
      workers: length(workers),
      monitors: :ets.info(monitors, :size),
      queued: :queue.len(waiting)
    }
    {:reply, status, state}
  end

  def handle_cast({:checkin, worker}, %{monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        Logger.info("Checking in worker #{inspect worker}.")
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_checkin(pid, state)
        {:noreply, new_state}
      [] ->
        Logger.info("Ignored request to checkin unknown worker #{inspect worker}.")
        {:noreply, state}
    end
  end

  def handle_info(:start_worker_supervisor, state = %{pool_sup: pool_sup,
  name: name, mfa: mfa, size: size}) do
    {:ok, worker_sup} =
      Supervisor.start_child(pool_sup, supervisor_spec(name, mfa))
    Logger.info("Worker supervisor #{name} now up.")
    workers = prepopulate(size, worker_sup)
    Logger.info("#{name} now populated with workers.")
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end
  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors,
  workers: workers}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        Logger.info("Worker process #{pid} down. Recovering now.")
        true = :ets.delete(monitors, pid)
        new_state = %{ state | workers: [ pid | workers ] }
        {:noreply, new_state}
      [[]] ->
        Logger.info("Unknown process down.")
        {:noreply, state}
    end
  end
  def handle_info({:EXIT, pid, _reason}, state = %{monitors: monitors}) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        Logger.info("Handling exit of worker #{inspect pid}.")
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = handle_worker_exit(pid, state)
        {:noreply, new_state}
      _ ->
        Logger.info("Unknown process #{pid} exited.")
        {:noreply, state}
    end
  end
  def handle_info({:EXIT, worker_sup, reason}, state =
  %{worker_sup: worker_sup}) do
    Logger.info("Worker supervisor exited. Stopping pool server.")
    {:stop, reason, state}
  end
  def handle_info(msg, state) do
    Logger.info("Pool server received unexpected message: #{inspect msg}")
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    Logger.info("Terminating pool server.")
    :ok
  end

  #####################
  # Private Functions #
  #####################

  defp state_name(%{workers: workers}) when length(workers) > 0, do: :ready
  defp state_name(%{max_overflow: max_overflow, overflow: overflow})
  when max_overflow > 0 and max_overflow > overflow, do: :overflow
  defp state_name(_), do: :full

  defp name(pool_name) do
    :"#{pool_name}Server"
  end

  defp supervisor_spec(name, mfa) do
    opts = [id: name <> "WorkerSupervisor", restart: :temporary]
    supervisor(Pooly.WorkerSupervisor, [self(), mfa], opts)
  end

  defp prepopulate(size, sup) do
    prepopulate(size, sup, [])
  end

  defp prepopulate(size, _sup, workers) when size < 1 do
    workers
  end
  defp prepopulate(size, sup, workers) do
    prepopulate(size - 1, sup, [new_worker(sup) | workers])
  end

  defp new_worker(sup) do
    {:ok, worker} = Supervisor.start_child(sup, [[]])
    true = Process.link(worker)
    worker
  end

  defp handle_checkin(pid, state) do
    %{
      monitors: monitors,
      overflow: overflow,
      waiting: waiting,
      workers: workers,
      worker_sup: worker_sup
    } = state

    case :queue.out(waiting) do
      {{:value, {from, ref}}, remaining} ->
        true = :ets.insert(monitors, {pid, ref})
        GenServer.reply(from, pid)
        Logger.info("Worker #{inspect pid} now being used by #{inspect from}.")
        %{state | waiting: remaining }

      {:empty, empty} when overflow > 0 ->
        :ok = dismiss_worker(worker_sup, pid)
        Logger.info("Overflow worker #{inspect pid} dismised.")
        %{ state | waiting: empty, overflow: overflow - 1 }

      {:empty, empty} ->
        Logger.info("Worker #{inspect pid} now waiting.")
        %{ state | waiting: empty, workers: [ pid | workers ], overflow: 0 }
    end
  end

  defp dismiss_worker(sup, pid) do
    true = Process.unlink(pid)
    Supervisor.terminate_child(sup, pid)
  end

  defp handle_worker_exit(_pid, state) do
    %{
      monitors: monitors,
      overflow: overflow,
      waiting: waiting,
      workers: workers,
      worker_sup: worker_sup
    } = state

    case :queue.out(waiting) do
      {{:value, {from, ref}}, remaining} ->
        new_worker = new_worker(worker_sup)
        true = :ets.insert(monitors, {new_worker, ref})
        GenServer.reply(from, new_worker)
        %{state | waiting: remaining }

      {:empty, empty} when overflow > 0 ->
        %{ state | waiting: empty, overflow: overflow - 1 }

      {:empty, empty} ->
        workers = [ new_worker(worker_sup) | workers ]
        %{ state | waiting: empty, workers: workers, overflow: 0 }
    end
  end
end

