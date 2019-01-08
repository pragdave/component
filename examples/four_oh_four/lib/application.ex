defmodule FourOhFour.Application do
  use Application

  def start(_, _) do
    children = [ V3.FourOhFour ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
