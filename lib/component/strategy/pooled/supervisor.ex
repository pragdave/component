defmodule Component.Strategy.Pooled.Supervisor do

  use Supervisor

  @doc """
  opts is a Keyword list containing:

  `name`: the name for this pool
  `worker_module`: the module containing the code for the worker_module
  `pool`:          a specification for the pool
  `min`: number of prestarted workers
  `max`: can add upto `max - min` demand-based workers
  """
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @dialyzer { :no_return, init: 1 }

  def init(opts) do
    exit_if_no_poolboy()

    worker_module = opts[:worker_module] || raise("missing worker module name")

    name  = opts[:name]      || MISSING_POOL_NAME
    pool  = opts[:pool_opts] || []
    min   = pool[:min]       || 2
    max   = pool[:max]       || (min+1) * 2
    state = opts[:state]     || %{}

    poolboy_config = [
      name:          { :local, name },
      worker_module: worker_module,
      size:          min,
      max_overflow:  max - min,
    ]

    children = [
      :poolboy.child_spec(name, poolboy_config, state),
    ]

    options = [
      strategy: :one_for_one,
      name: :pb_supervisor,
    ]
    Supervisor.init(children, options)
  end

  defp exit_if_no_poolboy() do
    try do
      :poolboy.child_spec(:a, [], [])
    rescue
      UndefinedFunctionError ->
        raise("""

        You are trying to create a pooled service, but you don't have `poolboy`
        listed as a dependency.

        You can add

        { :poolboy, "~> 1.5.0" }  # or a later version…

        to your dependencies to include it in your project.

        """)
    end
  end
end
