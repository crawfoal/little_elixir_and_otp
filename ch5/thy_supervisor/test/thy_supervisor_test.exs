defmodule ThySupervisorTest do
  use ExUnit.Case
  doctest ThySupervisor

  test "start_child/2" do
    {:ok, sup_pid} = ThySupervisor.start_link([])

    child_spec = {ThyWorker, :start_link, []}
    {:ok, child_pid} = sup_pid |> ThySupervisor.start_child(child_spec)

    assert sup_pid |> ThySupervisor.is_child?(child_pid)

    ThySupervisor.stop(sup_pid)
  end

  test "terminate_child/2" do
    {:ok, sup_pid} = ThySupervisor.start_link([])
    child_spec = {ThyWorker, :start_link, []}
    {:ok, child_pid} = sup_pid |> ThySupervisor.start_child(child_spec)

    :ok = sup_pid |> ThySupervisor.terminate_child(child_pid)

    refute sup_pid |> ThySupervisor.is_child?(child_pid)

    ThySupervisor.stop(sup_pid)
  end

  test "restart_child/3" do
    {:ok, sup_pid} = ThySupervisor.start_link([])
    child_spec = {ThyWorker, :start_link, []}
    {:ok, orig_child_pid} = sup_pid |> ThySupervisor.start_child(child_spec)

    {:ok, new_child_pid} =
      sup_pid |> ThySupervisor.restart_child(orig_child_pid, child_spec)

    assert sup_pid |> ThySupervisor.is_child?(new_child_pid)
    refute sup_pid |> ThySupervisor.is_child?(orig_child_pid)

    ThySupervisor.stop(sup_pid)
  end

  test "count_children/1" do
    {:ok, sup_pid} = ThySupervisor.start_link([])
    child_spec = {ThyWorker, :start_link, []}
    {:ok, _child1_pid} = sup_pid |> ThySupervisor.start_child(child_spec)
    {:ok, _child2_pid} = sup_pid |> ThySupervisor.start_child(child_spec)

    assert sup_pid |> ThySupervisor.count_chldren() == 2

    ThySupervisor.stop(sup_pid)
  end

  test "which_children/1" do
    {:ok, sup_pid} = ThySupervisor.start_link([])
    child_spec = {ThyWorker, :start_link, []}
    {:ok, child1_pid} = sup_pid |> ThySupervisor.start_child(child_spec)
    {:ok, child2_pid} = sup_pid |> ThySupervisor.start_child(child_spec)

    assert %{^child1_pid => ^child_spec, ^child2_pid => ^child_spec} =
      sup_pid |> ThySupervisor.which_children()

    ThySupervisor.stop(sup_pid)
  end

  test "crashed process is restarted automatically" do
    {:ok, sup_pid} = ThySupervisor.start_link([])
    child_spec = {ThyWorker, :start_link, []}
    {:ok, child_pid} = sup_pid |> ThySupervisor.start_child(child_spec)

    send(child_pid, :crash)

    assert ThySupervisor.count_chldren(sup_pid) == 1
    [new_child_pid] = ThySupervisor.which_children(sup_pid) |> Map.keys()
    refute new_child_pid == child_pid

    ThySupervisor.stop(sup_pid)
  end
end
