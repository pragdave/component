defmodule Component.Strategy.Pooled do

  @moduledoc """
  Implement a named pool of services. The current implementation
  delegates the heavy lifting to
  [poolboy](https://github.com/devinus/poolboy)

  ### Usage

  To create the service:

  * Create a module that implements the API you want. This API will be
    expressed as a set of public functions. Each function will
    automatically receive the current state in a variable (by default
    named `state`). There is not need to declare this as a
    parameter.[<small>why?</small>](#why-magic-state). If a function
    wants to change the state, it must end with a call to the
    `set_state/2` function (which will have been imported into your
    module automatically).

    For this example, we'll call the module `Workers`.

  * Add the line `use Component.Strategy.Pooled` to the top of this
    module.

  * Adjust the other options if required.

  * To start the pool:

        Workers.initialize()

    or

        Workers.initialize(initial_state)

  * Claim a worker using

       worker = Workers.create()

  * Call functions in the module using

       result = Workers.some_function(worker, other_args)
       ...

  * When you're finished with the worker, call

      Workers.destroy(worker)

  (The `create` and `destroy` functions correspond to poolboy's
  `checkout` and `checkin`. We use these names for consistency with
  other strategies.)

  ### Example

      defmodule FaceDetector do
        using Component.Strategy.Pooled,
              state: %{ algorithm: ViolaJones },
              state_name: :options,
              pool:  [ min: 3, max: 10 ]

        def recognize(image) do
          # calls to OpenCV or whatever...
        end
      end

  ### Options

  You can pass a keyword list to `use Component.Strategy.Pooled:`

  * `initial_state:` _value_

    The default value for the initial state of all workers. Can be
    overridden (again for all workers) by passing a value to
    `initialize()`

  * `state_name:` _atom_

    The default name for the state variable is (unimaginatively)
    `state`. Use `state_name` to override this. For example, the
    previous example named the state `options`, and inside the
    `recognize` function your could write `options.algorithm` to look up
    the algorithm to use.

  * `service_name:` _atom_

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

  alias Component.{ CodeGenHelper, Strategy }
  alias Component.Strategy.Dynamic

  @behaviour Strategy

  @doc false
  defmacro __using__(opts \\ []) do
    Strategy.handle_using(opts, __CALLER__.module, __MODULE__)
  end

  @doc """
  Called from Strategy.parse_options to parse additional options
  specific to this strategy.
  """
  @impl Strategy
  @spec parse_options(Map.t, Keyword.t, atom) :: Map.t
  def parse_options(options_so_far, options_from_using, _target_module) do
    pool    = Keyword.get(options_from_using, :pool, [ min: 1, max: 2 ])
    options_so_far
    |> Map.put(:pool, pool)
  end


  @doc """
  Generate the code for a Global server.
  """

  @impl Strategy
  @spec emit_code(functions :: map, target_module :: atom, options :: map ) :: Strategy.quoted_code

  def emit_code(generated, _target_module, options) do
    pooled = Component.Strategy.Pooled

    quote do
      @name unquote(options.service_name)

      def initialize() do
        initialize(unquote(options.initial_state))
      end

      def initialize(state) do
        unquote(pooled).Scheduler.start_new_pool(
          worker_module: __MODULE__.Worker,
          pool_opts:     unquote(options.pool),
          name:          @name,
          state:         state)
      end

      def create()  do
        unquote(pooled).Scheduler.checkout(@name)
      end

      def destroy(worker) do
        unquote(pooled).Scheduler.checkin(@name, worker)
      end

      unquote_splicing(generated.apis)

      defmodule Worker do
        use GenServer


        def start_link(args) do
          GenServer.start_link(__MODULE__, args)
        end

        def init(state) do
          { :ok, state }
        end

        unquote_splicing(generated.handlers)
        defmodule Implementation do
          unquote_splicing(generated.implementations)
        end

      end
    end
  end


 #############################
 # Function code generators  #
 #############################
  @impl Strategy
  def generate_api_call(options, {one_or_two_way, call, _body}) do
    args_with_pid = signature_with_pid(call, options)
    quote do
      def(unquote(args_with_pid), do: unquote(Dynamic.api_body(one_or_two_way, options, call)))
    end
  end


  @doc false
  @impl Strategy
  defdelegate generate_handle_call(options,function),    to: CodeGenHelper

  @doc false
  @impl Strategy
  defdelegate generate_implementation(options,function), to: CodeGenHelper

  @doc false
  @impl Strategy
  def generate_delegator(options, {_one_or_two_way, call, _body}) do
    quote do
      def unquote(call), do: unquote(delegate_body(options, call))
    end
  end


  # Prepend `worker_pid` to the calling sequence of a function
  # definition
  defp signature_with_pid({ name, context, args }, options) do
    args = CodeGenHelper.args_without_state(args, options)
    { name, context, [ { :worker_pid, [line: 1], nil } | args ]}
  end

  @doc false
  defp delegate_body(options, call) do
    timeout = options[:timeout] || 5000
    request = CodeGenHelper.call_signature(call, options)
    quote do
      Component.Scheduler.run(@name, unquote(request), unquote(timeout))
    end
  end

end
