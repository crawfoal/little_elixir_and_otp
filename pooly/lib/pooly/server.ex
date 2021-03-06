defmodule Pooly.Server do
  use GenServer
  import Supervisor.Spec

  alias Pooly.{PoolSupervisor, PoolsSupervisor}

  defmodule State do
    defstruct sup: nil, size: nil, mfa: nil, monitors: nil, worker_sup: nil,
      workers: []
  end

  #######
  # API #
  #######

  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def checkout(pool_name, block, timeout) do
    Pooly.PoolServer.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, ticket) do
    GenServer.cast(:"#{pool_name}Server", {:checkin, ticket})
  end

  def status(pool_name) do
    GenServer.call(:"#{pool_name}Server", :status)
  end

  def transaction(pool_name, fun, args, block, timeout) do
    ticket = checkout(pool_name, block, timeout)
    try do
      apply(fun, args)
    after
      checkin(pool_name, ticket)
    end
  end

  #############
  # Callbacks #
  #############

  def init(pools_config) do
    pools_config |> Enum.each(fn(pool_config) ->
      send(self(), {:start_pool, pool_config})
    end)

    {:ok, pools_config}
  end

  def handle_info({:start_pool, pool_config}, state) do
    {:ok, _pool_sup} =
      Supervisor.start_child(PoolsSupervisor, supervisor_spec(pool_config))
    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################

  defp supervisor_spec(pool_config) do
    opts = [id: :"#{pool_config[:name]}Supervisor"]
    supervisor(PoolSupervisor, [pool_config], opts)
  end
end

