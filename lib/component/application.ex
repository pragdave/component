defmodule Component.Application do

  use Application

  def start(_type, _args) do
    # children = [ ]
    # opts = [strategy: :one_for_one, name: Component.Supervisor]
    # Supervisor.start_link(children, opts)
    { :ok, self() }
  end
end
