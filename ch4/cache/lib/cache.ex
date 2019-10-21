defmodule Cache do
  @moduledoc """
  An in memory key value store implemented with GenServer.
  """

  use GenServer

  ## Client API

  @doc """
  Start a server for the cache.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Asynchronously write a key, value pair to the cache.
  """
  def write(pid, key, value) do
    GenServer.cast(pid, {:write, key, value})
  end

  @doc """
  Asynchronously delete a key from the cache.
  """
  def delete(pid, key) do
    GenServer.cast(pid, {:delete, key})
  end

  @doc """
  Asynchronously clear the cache.
  """
  def clear(pid) do
    GenServer.cast(pid, :clear)
  end

  @doc """
  Read a value from the cache.
  """
  def read(pid, key) do
    GenServer.call(pid, {:read, key})
  end

  @doc """
  Check to see if a key exists in the cache.
  """
  def exists?(pid, key) do
    GenServer.call(pid, {:exists?, key})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast({:write, key, value}, cache) do
    {:noreply, cache |> Map.put(key, value)}
  end
  def handle_cast({:delete, key}, cache) do
    {:noreply, cache |> Map.delete(key)}
  end
  def handle_cast(:clear, _cache) do
    {:noreply, %{}}
  end

  def handle_call({:read, key}, _, cache) do
    {:reply, cache |> Map.get(key), cache}
  end
  def handle_call({:exists?, key}, _, cache) do
    {:reply, cache |> Map.has_key?(key), cache}
  end

  ## Helper Functions
end
