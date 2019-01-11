defmodule Component.Strategy.Global do

  @moduledoc """
  Implement a singleton (global) named service.

  ### Usage

  To create the service:

  * Create a module that implements the API you want. This API will be
    expressed as a set of public functions. Each function will
    automatically receive the current state in a variable (by default
    named `state`). There is not need to declare this as a parameter.
    ([see why](background.html#why-magic-state)) If a function wants to
    change the state, it must end with a call to the `set_state/2` or
    `set_state_and_return` function (which will have been imported into
    your module automatically).

    For this example, we'll call the module `GlobalService`.

  * Add the line `use Common.Strategy.Global` to the top of this module.

  To consume the service:

  * Create an instance of the service with `GlobalService.create()`. You
    can pass initial state to the service as an optional parameter. This
    call returns a handle to this service instance, but you shouldn't
    use it.

  * Call the API functions in the service.


  ### Example

      defmodule KV do
        using Common.Strategy.Global, initial_state: %{}

        def get(name), do: state[name]
        def put(name, value) do
          set_state(Map.put(state, name, value)) do
            value
          end
        end
      end

      KV.create(%{ name: "Elixir" })
      KV.put(:type, "language")
      KV.get(:name)    # => "Elixir"
      KV.get(:type)    # => "language"


  ### Options

  You can pass a keyword list to `use Component.Strategy.Global`:

  * `initial_state:` _value_

  * `state_name:` _atom_

    The default name for the state variable is (unimaginatively)
    `state`. Use `state_name` to override this. For example, you could
    change the previous example to use `store` for the state with:

        defmodule KV do
          using Component.Strategy.Global,
                initial_state: %{},
                state_name:    :store

          def get(name), do: store[name]
          def put(name, value) do
            set_state(Map.put(store, name, value)) do
              value
            end
          end
        end

  * `service_name:` _atom_

    The default name for the service is the name of the module that
    defines it. Use `service_name:` to change this.

  * `timeout:`  _timeout_
    The timeout that will apply to calls to `two_way` functions.

    If you pass a float, then it is the time in seconds.

    If you pass an integer, then it'sm the time in milliseconds.

    Defaults to 5.0 seconds

  * `show_code:` _boolean_

    If truthy, dump a representation of the generated code to STDOUT
    during compilation.

  """

  alias   Component.CodeGenHelper
  alias   Component.Strategy
  alias   Component.Strategy.Common
  require Common

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
  def parse_options(options_so_far, _options_from_using, _target_module) do
    options_so_far
  end

  @doc """
  Generate the code for a Global server.
  """

  @impl Strategy
  @spec emit_code(functions :: map, target_module :: atom, options :: map ) :: Strategy.quoted_code

  def emit_code(generated, _target_module, options) do

    service_name = options.service_name

    name_opt = quote do: { :via, :global, unquote(service_name) }
    server_opts = quote do
      [ name: unquote(name_opt) ]
    end

    application = CodeGenHelper.maybe_create_application(options)

    quote do
      use GenServer

      unquote(application)

      def create() do
        create(unquote(options.initial_state))
      end

      def create(state) do
        { :ok, pid } = GenServer.start_link(__MODULE__, state, unquote(server_opts))
        pid
      end

      # the normal api removes the :ok, but we need it when starting
      # under a supervisor
      def wrapped_create() do
        { :ok, create() }
      end

      def destroy() do
        GenServer.stop(unquote(name_opt))
      end

      def start_link(state_override) do
        { :ok, create(state_override) }
      end

      def init(state) do
        { :ok, state }
      end

      defoverridable(init: 1)

      unquote(generated.callbacks)
      unquote_splicing(generated.apis)
      unquote_splicing(generated.handlers)

      defmodule Implementation do
        unquote_splicing(generated.implementations)
      end
    end
  end


  @doc false
  @impl Strategy
  def generate_api_call(options, {one_or_two_way, call, _body}) do
    { name, context, args } = call
    call = { name, context, CodeGenHelper.args_without_state(args, options) }
    quote do
      def(unquote(call), do: unquote(api_body(one_or_two_way, options, call)))
    end
  end

  @doc false
  defp api_body(:one_way, options, call) do
    request = CodeGenHelper.call_signature(call, options)
    quote do
      GenServer.cast(
        { :via, :global, unquote(service_name(options)) },
        unquote(request))
    end
  end

  defp api_body(:two_way, options, call) do
    request = CodeGenHelper.call_signature(call, options)
    quote do
      GenServer.call(
        { :via, :global, unquote(service_name(options)) },
        unquote(request),
        unquote(options.timeout))
    end
  end


  @doc false
  @impl Strategy
  defdelegate generate_handle_call(options,function),    to: CodeGenHelper

  @doc false
  @impl Strategy
  defdelegate generate_implementation(options,function), to: CodeGenHelper

  # only used for pools
  @doc false
  @impl Strategy
  def generate_delegator(_options, {_one_or_two_way, _call, _body}), do: nil


  # given def fred(a, b) return def fred(«state name», a, b)


  @doc false
  defp service_name(options) do
    options[:service_name] || quote(do: __MODULE__)
  end

end
