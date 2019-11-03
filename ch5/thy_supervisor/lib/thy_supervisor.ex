defmodule ThySupervisor do
  use GenServer

  #######
  # API #
  #######

  def start_link(child_spec_list) do
    GenServer.start_link(__MODULE__, [child_spec_list])
  end

  def start_child(supervisor, child_spec) do
    GenServer.call(supervisor, {:start_child, child_spec})
  end

  def terminate_child(supervisor, pid) when is_pid(pid) do
    GenServer.call(supervisor, {:terminate_child, pid})
  end

  def restart_child(supervisor, pid, child_spec) when is_pid(pid) do
    GenServer.call(supervisor, {:restart_child, pid, child_spec})
  end

  def count_chldren(supervisor) do
    GenServer.call(supervisor, :count_chldren)
  end

  def which_children(supervisor) do
    GenServer.call(supervisor, :which_children)
  end

  def is_child?(supervisor, pid) when is_pid(pid) do
    GenServer.call(supervisor, {:is_child?, pid})
  end

  def stop(supervisor, reason \\ :normal) do
    GenServer.stop(supervisor, reason)
  end

  ######################
  # Callback Functions #
  ######################

  def init([child_spec_list]) do
    Process.flag(:trap_exit, true)
    state = child_spec_list |> start_children() |> Enum.into(%{})
    {:ok, state}
  end

  def handle_call({:start_child, child_spec}, _from, state) do
    case start_child(child_spec) do
      {:ok, pid} ->
        new_state = state |> Map.put(pid, child_spec)
        {:reply, {:ok, pid}, new_state}
      :error ->
        {:reply, {:error, "error starting child"}, state}
    end
  end
  def handle_call({:terminate_child, pid}, _from, state) do
    case terminate_child(pid) do
      :ok ->
        new_state = state |> Map.delete(pid)
        {:reply, :ok, new_state}
      :error ->
        {:reply, {:error, "error terminating child"}, state}
    end
  end
  def handle_call({:restart_child, old_pid, child_spec}, _from, state) do
    case do_restart_child(old_pid, child_spec, state) do
      {:ok, pid, new_state} -> {:reply, {:ok, pid}, new_state}
      :error -> {:reply, {:error, "error restarting child"}, state}
      :noproc -> {:reply, :ok, state}
    end
  end
  def handle_call(:count_chldren, _from, state) do
    {:reply, Map.size(state), state}
  end
  def handle_call(:which_children, _from, state) do
    {:reply, state, state}
  end
  def handle_call({:is_child?, pid}, _from, state) do
    case Map.fetch(state, pid) do
      {:ok, _pid} ->
        {:reply, true, state}
      _ ->
        {:reply, false, state}
    end
  end

  def handle_info({:EXIT, from, :killed}, state) do
    new_state = state |> Map.delete(from)
    {:noreply, new_state}
  end
  def handle_info({:EXIT, from, :normal}, state) do
    new_state = state |> Map.delete(from)
    {:noreply, new_state}
  end
  def handle_info({:EXIT, old_pid, _reason}, state) do
    case restart_child(old_pid, state) do
      {:ok, _pid, new_state} -> {:noreply, new_state}
      _ -> {:noreply, state}
    end
  end

  def terminate(_reason, state) do
    terminate_children(state)
    :ok
  end

  #####################
  # Private Functions #
  #####################

  defp start_children([child_spec | rest]) do
    case start_child(child_spec) do
      {:ok, pid} ->
        [{pid, child_spec} | start_child(rest)]
      :error ->
        :error
    end
  end
  defp start_children([]), do: []

  defp start_child({mod, fun, args}) do
    case apply(mod, fun, args) do
      pid when is_pid(pid) ->
        Process.link(pid)
        {:ok, pid}
      _ ->
        :error
    end
  end

  defp terminate_children([]) do
    :ok
  end
  defp terminate_children(state) do
    state |> Enum.each(fn {pid, _} -> terminate_child(pid) end)
  end

  defp terminate_child(pid) do
    Process.exit(pid, :kill)
    :ok
  end

  defp restart_child(pid, state) when is_pid(pid) and is_map(state) do
    case Map.fetch(state, pid) do
      {:ok, child_spec} ->
        do_restart_child(pid, child_spec, state)
      _ ->
        :noproc
    end
  end
  defp restart_child(pid, child_spec) when is_pid(pid) do
    :ok = terminate_child(pid)
    case start_child(child_spec) do
      {:ok, new_pid} ->
        {:ok, {new_pid, child_spec}}
      :error ->
        {:error, :failure_starting_child}
    end
  end

  defp do_restart_child(old_pid, child_spec, state) do
    with {:ok, _child_spec} <- Map.fetch(state, old_pid),
         {:ok, {pid, child_spec}} <- restart_child(old_pid, child_spec)
    do
      new_state = state |> Map.delete(old_pid) |> Map.put(pid, child_spec)
      {:ok, pid, new_state}
    else
      {:error, :failure_starting_child} -> :error
      :error -> :noproc
    end
  end
end
