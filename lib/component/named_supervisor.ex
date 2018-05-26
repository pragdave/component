defmodule Component.NamedSupervisor do

  @moduledoc """
  This module allows you to create one or more named dynamic
  supervisors. Each of these will manage a set of workers.
  """

  def run(params) do
    children = [
      {
        DynamicSupervisor,
        name:      params[:name] || :no_name,
        strategy: :one_for_one
      }
    ]

     { :ok, _stuff } = Supervisor.start_link(children, strategy: :one_for_one)
  end

  def create(supervisor, child_spec) do
    { :ok, pid } = DynamicSupervisor.start_child(supervisor, child_spec)
    pid
  end

  def destroy(supervisor, worker) do
    DynamicSupervisor.terminate_child(supervisor, worker)
  end
end
