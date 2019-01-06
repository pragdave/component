false && defmodule Component.Strategy.SharedPool do

  @moduledoc """
  Implement a singleton (global) named pool of services.

  Creates a dynamic pool of worker services. Each service shares an
  initial state, and each invocation of a service is independent from
  the previous one (so there is no concept of claiming a service for
  your dedicated use).

  ### Prerequisites

  You'll need to add poolboy to your project dependencies.

  ### Usage

  To create the service:

  * Create a module that implements the API you want. This API will be
    expressed as a set of public functions. Each function will
    automatically receive the current state in a variable (by default
    named `state`). There is not need to declare this as a
    parameter.[<small>why?</small>](#why-magic-state). If a function
    wants to change the state, it must end with a call to the
    `update_state/2` function (which will have been imported into your
    module automatically).

    For this example, we'll call the module `PooledService`.

  * Add the line `use Component.Strategy.Pooled` to the top of this module.

  * Adjust the other options if required.

    To start the pool:

        PooledService.run()

    or

        PooledService.run(initial_state)

  To consume the service:

  * Call the API functions in the service.


  ### Example

      defmodule FaceDetector do
        use Component.Strategy.Pooled,
              state: %{ algorithm: ViolaJones },
              state_name: :options,
              pool:  [ min: 3, max: 10 ]

        def recognize(image) do
          # calls to OpenCV or whatever...
        end
      end

  ### Options

  You can pass a keyword list to `use Component.Strategy.Pooled:`

  * `state:` _value_

    The default value for the initial state of all workers. Can be
    overridden (again for all workers) by passing a value to `run()`

  * `state_name:` _atom_

    The default name for the state variable is (unimaginatively)
    `state`. Use `state_name` to override this. For example, the
    previous example named the state `options`, and inside the
    `recognize` function your could write `options.algorithm` to look up
    the algorithm to use.

  * `name:` _atom_

    The default name for the pool is the name of the module that defines
    it. Use `name:` to change this.

  * `pool: [ ` _options_ ` ]`

    Set options for the service pool. One or more of:

    * `min: n`

      The minimum number of workers that should be active, and by
      extension the number of workers started when the pool is run.
      Default is 2.

    * `max: n`

      The maximum number of workers. If all workers are busy and a new
      request arrives, a new worker will be started to handle it if the
      current worker count is less than `max`. Excess idle workers will
      be quietly killed off in the background. Default value is
      `(min+1)*2`.

  * `showcode:` _boolean_

    If truthy, dump a representation of the generated code to STDOUT
    during compilation.

  * `timeout:` integer or float

    Specify the timeout to be used when the client calls workers in the
    pool. If all workers are busy, and none becomes free in that time,
    an OTP exception is raised. An integer specifies the timeout in
    milliseconds, and a float in seconds (so 1.5 is the same as 1500).

  """


  alias Component.Strategy.PreprocessorState, as: PS
  alias Component.Strategy.{Common, Global}

  @doc false
  defmacro __using__(opts \\ []) do
    generate_pooled_service(__CALLER__.module, opts)
  end

  @doc false
  def generate_pooled_service(caller, opts) do
    name  = Keyword.get(opts, :service_name,  :no_name)
    state = Keyword.get(opts, :initial_state, :no_state)

    PS.start_link(caller, opts)

    quote do
      import Component.Strategy.Common,
              only: [
                one_way:              2,
                two_way:              2,
                set_state_and_return: 1,
                set_state:            2
              ]

      @before_compile { unquote(__MODULE__), :generate_code }

      @name unquote(name)

      def run() do
        run(unquote(state))
      end

      def run(state) do
        Component.Scheduler.start_new_pool(
          worker_module: __MODULE__.Worker,
          pool_opts:     unquote(opts[:pool] || [ min: 1, max: 4]),
          name:          @name,
          state:         state)
      end
    end
    |> Common.maybe_show_generated_code(opts)
  end

  @doc false
  defmacro generate_code(_) do

    { options, apis, handlers, implementations, delegators } =
      Common.create_functions_from_originals(__CALLER__.module, __MODULE__)

    PS.stop(__CALLER__.module)

    quote do

      unquote_splicing(delegators)

      defmodule Worker do
        use GenServer

        def start_link(args) do
          GenServer.start_link(__MODULE__, args)
        end

        unquote_splicing(apis)
        unquote_splicing(handlers)
        defmodule Implementation do
          unquote_splicing(implementations)
        end

      end
    end
    |> Common.maybe_show_generated_code(options)
  end

  @doc false
  defdelegate generate_api_call(options,function),       to: Global
  @doc false
  defdelegate generate_handle_call(options,function),    to: Global
  @doc false
  defdelegate generate_implementation(options,function), to: Global

  @doc false
  def generate_delegator(options, {one_or_two_way, call, _body}) do
    quote do
      def unquote(call), do: unquote(delegate_body(options, call))
    end
  end


  @doc false
  def delegate_body(options, call) do
    timeout = options[:timeout] || 5000
    request = Global.call_signature(call)
    quote do
      Component.Scheduler.run(@name, unquote(request), unquote(timeout))
    end
  end

end
