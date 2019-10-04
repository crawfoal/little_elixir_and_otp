defmodule Metex do

  def temperature_of(locations) do
    coordinator_pid =
      spawn(Metex.Coordinator, :loop, [[], Enum.count(locations)])

    locations |> Enum.each(fn location ->
      worker_pid = spawn(Metex.Worker, :loop, [])
      send worker_pid, {coordinator_pid, location}
    end)
  end
end
