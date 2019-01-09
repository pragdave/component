defmodule Component.Strategy.Dynamic do

  @moduledoc """
  Implement a service factory, which you can use to create any number of workers.

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

  * Add the line `use Component.Strategy.Dynamic` to the top of this
    module.

  * Adjust the other options if required.

  * To start the worker supervisor:

      ```
      Workers.initialize()
      ```

    or

      ```
      Workers.initialize(initial_state)
      ```

  * Claim a worker using

      ```
      worker = Workers.create()
      ```

  * Call functions in the module using

      ```
      result = Workers.some_function(worker, other_args)
      ...
      ```

  * When you're finished with the worker, call

      ```
      Workers.destroy(worker)
      ```


  ### Example

      defmodule FaceDetector do
        using Component.Strategy.Dynamic

              state: %{ algorithm: ViolaJones },
              state_name: :options,

        def recognize(image) do
          # calls to OpenCV or whatever...
        end
      end

  ### Options

  You can pass a keyword list to `use Component.Strategy.Dynamic`:

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

  * `name:` _atom_

    The default name for the pool is the name of the module that defines
    it. Use `name:` to change this.


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
  alias Common.CommonAttribute, as: CA

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
                callbacks:            1,
                one_way:              2,
                two_way:              2,
                set_state_and_return: 1,
                set_state:            2
              ]


      @before_compile { unquote(__MODULE__), :generate_code }

      @name unquote(name)

      def initialize() do
        Component.Strategy.Dynamic.Supervisor.run(
          worker_module: __MODULE__.Worker,
          name:          @name)
      end

      def create(override_state \\ CA.no_overrides)  do
        spec = {
          __MODULE__.Worker,
          Common.derive_state(override_state, unquote(default_state)),
        }
        Component.Strategy.Dynamic.Supervisor.create(@name, spec)
      end

      def destroy(worker) do
        Component.Strategy.Dynamic.Supervisor.destroy(@name, worker)
      end

    end
    |> Common.maybe_show_generated_code(opts)
  end

  @doc false
  defmacro generate_code(_) do

    caller_name = __CALLER__.module

    { options, apis, handlers, implementations, _delegators } =
      Common.create_functions_from_originals(caller_name, __MODULE__)

    callbacks = PS.get_callbacks(caller_name)

    PS.stop(caller_name)

    application = Common.maybe_create_application(options)

    quote do
      unquote(application)
      unquote_splicing(apis)

      def wrapped_create() do
        initialize()
      end

      defmodule Worker do
        use GenServer


        def start_link(args) do
          GenServer.start_link(__MODULE__, args)
        end

        def init(state) do
          { :ok, state }
        end

        defoverridable(init: 1)

        unquote(callbacks)

        unquote_splicing(handlers)

        defmodule Implementation do
          unquote_splicing(implementations)
        end

      end
    end
    |> Common.maybe_show_generated_code(options)
  end

  def generate_api_call(options, {one_or_two_way, call, _body}) do
    args_with_pid = signature_with_pid(call, options)
    quote do
      def(unquote(args_with_pid), do: unquote(api_body(one_or_two_way, options, call)))
    end
  end

  # Prepend `worker_pid` to the calling sequence of a function
  # definition
  defp signature_with_pid({ name, context, args }, options) do
    args = Global.args_without_state(args, options)
    { name, context, [ { :worker_pid, [line: 1], nil } | args ]}
  end

  @doc false
  def api_body(:one_way, options, call) do
    request = Global.call_signature(call, options)
    pid_var = { :worker_pid, [], nil }
    quote do
      GenServer.cast(unquote(pid_var), unquote(request))
    end
  end


  def api_body(:two_way, options, call) do
    request = Global.call_signature(call, options)
    pid_var = { :worker_pid, [], nil }
    quote do
      GenServer.call(unquote(pid_var), unquote(request), unquote(genserver_timeout(options)))
    end
  end

  # given def fred(a, b) return { :fred, a, b }
  @doc false
  # def call_signature({ name, _, args }, options) do
  #   args
  #   |> Global.args_without_state(options)
  #   |> Enum.map(fn name -> var!(name) end)
  #   { :{}, [], [ name |  args ] }
  # end


  defp genserver_timeout(options) do
    case options[:timeout] do
      nil ->
        5_000
      i when is_integer(i) ->
        i
      f when is_float(f) ->
        :math.floor(f * 1000.0)
      other ->
        raise "Expecting integer or float for timeout value, but got #{inspect other}"
    end
  end

  @doc false
  defdelegate generate_handle_call(options,function),    to: Global
  @doc false
  defdelegate generate_implementation(options,function), to: Global

  @doc false
  def generate_delegator(options, {_one_or_two_way, call, _body}) do
    quote do
      def unquote(call), do: unquote(delegate_body(options, call))
    end
  end


  @doc false
  def delegate_body(options, call) do
    timeout = options[:timeout] || 5000
    request = Global.call_signature(call, options)
    quote do
      Component.Scheduler.run(@name, unquote(request), unquote(timeout))
    end
  end


end
