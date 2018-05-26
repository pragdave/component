defmodule Component.Strategy.Named do

  @moduledoc """
  Implement a named service. You can create any number of workers
  based on the service.

  ### Usage

  To create the service:

  * Create a module that implements the API you want. This API will be
    expressed as a set of public functions. Each function will automatically
    receive the current state in a variable (by default named `state`). There is
    not need to declare this as a parameter.[<small>why?</small>](#why-magic-state).
    If a function wants to change the state, it must end with a call to the
    `set_state/2` function (which will have been
    imported into your module automatically).

    For this example, we'll call the module `Workers`.

  * Add the line `use Component.Strategy.Named` to the top of this module.

  * Adjust the other options if required.

  * To start the worker supervisor:

        Workers.run()

    or

        Workers.run(initial_state)

  * Claim a worker using

       worker = Workers.create()

  * Call functions in the module using

       result = Workers.some_function(worker, other_args)
       ...

  * When you're finished with the worker, call

      Workers.destroy(worker)



  ### Example

      defmodule FaceDetector do
        using Jeeves.Named
              state: %{ algorithm: ViolaJones },
              state_name: :options,
              pool:  [ min: 3, max: 10 ]

        def recognize(image) do
          # calls to OpenCV or whatever...
        end
      end

  ### Options

  You can pass a keyword list to `use Jeeves.Anonymous:`

  * `state:` _value_

    The default value for the initial state of all workers. Can be overridden
    (again for all workers) by passing a value to `run()`

  * `state_name:` _atom_

    The default name for the state variable is (unimaginatively)  `state`.
    Use `state_name` to override this. For example, the previous
    example named the state `options`, and inside the `recognize` function
    your could write `options.algorithm` to look up the algorithm to use.

  * `name:` _atom_

    The default name for the pool is the name of the module that defines it.
    Use `name:` to change this.

  * `pool: [ ` _options_ ` ]`

    Set options for the service pool. One or more of:

    * `min: n`

      The minimum number of workers that should be active, and by extension
      the number of workers started when the pool is run. Default is 2.

    * `max: n`

      The maximum number of workers. If all workers are busy and a new request
      arrives, a new worker will be started to handle it if the current worker
      count is less than `max`. Excess idle workers will be quietly killed off
      in the background. Default value is `(min+1)*2`.

  * `showcode:` _boolean_

    If truthy, dump a representation of the generated code to STDOUT during
    compilation.

  * `timeout:` integer or float

    Specify the timeout to be used when the client calls workers in the pool.
    If all workers are busy, and none becomes free in that time, an OTP
    exception is raised. An integer specifies the timeout in milliseconds, and
    a float in seconds (so 1.5 is the same as 1500).

  """


  alias Component.Strategy.PreprocessorState, as: PS
  alias Component.Strategy.{Common, Global}

  @doc false
  defmacro __using__(opts \\ []) do
    generate_named_service(__CALLER__.module, opts)
  end

  @doc false
  def generate_named_service(caller, opts) do
    name          = Keyword.get(opts, :service_name,  caller)
    default_state = Keyword.get(opts, :initial_state, :no_state)

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
        Component.NamedSupervisor.run(
          worker_module: __MODULE__.Worker,
          name:          @name)
      end

      def create(state \\ unquote(default_state))  do
        spec = {
          __MODULE__.Worker,
          state,
        }
        Component.NamedSupervisor.create(@name, spec)
      end

      def destroy(worker) do
        Component.NamedSupervisor.destroy(@name, worker)
      end

    end
    |> Common.maybe_show_generated_code(opts)
  end

  @doc false
  defmacro generate_code(_) do

    { options, apis, handlers, implementations, _delegators } =
      Common.create_functions_from_originals(__CALLER__.module, __MODULE__)

    PS.stop(__CALLER__.module)

    quote do

      unquote_splicing(apis)

      defmodule Worker do
        use GenServer


        def start_link(args) do
          GenServer.start_link(__MODULE__, args)
        end

        def init(state) do
          { :ok, state }
        end

        unquote_splicing(handlers)
        defmodule Implementation do
          unquote_splicing(implementations)
        end

      end
    end
    |> Common.maybe_show_generated_code(options)
  end

  def generate_api_call(options, {one_or_two_way, call, _body}) do
    args_with_pid = signature_with_pid(call)
    quote do
      def(unquote(args_with_pid), do: unquote(api_body(one_or_two_way, options, call)))
    end
  end

  # Prepend `worker_pid` to the calling sequence of a function
  # definition
  defp signature_with_pid({ name, context, args }) do
    { name, context, [ { :worker_pid, [line: 1], nil } | args ]}
  end

  @doc false
  defp api_body(one_or_two_way, _options, call) do
    request = call_signature(call)
    pid_var = { :worker_pid, [], nil }
    quote do
      GenServer.unquote(invocation(one_or_two_way))(unquote(pid_var), unquote(request))
    end
  end

  # given def fred(a, b) return { :fred, a, b }
  @doc false
  def call_signature({ name, _, args }) do
    args = args |> Enum.map(fn name -> var!(name) end)
    { :{}, [], [ name |  args ] }
  end


  defp invocation(:one_way), do: :cast
  defp invocation(:two_way), do: :call


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
