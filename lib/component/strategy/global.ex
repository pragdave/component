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

  * `show_code:` _boolean_

    If truthy, dump a representation of the generated code to STDOUT
    during compilation.

  """


  alias   Component.Strategy.Common
  alias   Component.Strategy.PreprocessorState, as: PS
  require Common

  @doc false
  defmacro __using__(opts \\ []) do
    generate_global_service(__CALLER__.module, opts)
  end

  @doc false
  def generate_global_service(caller, opts) do
    name          = Keyword.get(opts, :service_name,  caller)
    default_state = Keyword.get(opts, :initial_state, :no_state)

    PS.start_link(caller, opts)

    name_opt = quote do: { :via, :global, unquote(name) }

    server_opts = if name do
        quote do
          [ name: unquote(name_opt) ]
        end
      else
         [ ]
      end

    quote do

        import Component.Strategy.Common,
               only: [ callbacks: 1, one_way: 2, two_way: 2, set_state_and_return: 1, set_state: 2 ]

        @before_compile { unquote(__MODULE__), :generate_code_callback }

        @doc """
        This is a simple flag function that identifies this module
        as implementing a component.
        """

        def unquote(Component.info_function_name())() do
          %{
            strategy: unquote(__MODULE__),
            name:     unquote(name),
            opts:     unquote(opts),
          }
        end

        def create() do
          create(unquote(default_state))
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

        # def server_opts() do
        #   unquote(server_opts)
        # end
      end
      |> Common.maybe_show_generated_code(opts)
    end

  @doc false
  defmacro generate_code_callback(_module_env) do
    Common.generate_code(__CALLER__.module, __MODULE__)
  end

  @doc false
  def generate_api_call(options, {one_or_two_way, call, _body}) do
    { name, context, args } = call
    call = { name, context, args_without_state(args, options) }
    quote do
      def(unquote(call), do: unquote(api_body(one_or_two_way, options, call)))
    end
  end

  @doc false
  defp api_body(one_or_two_way, options, call) do
    request = call_signature(call, options)
    quote do
      GenServer.unquote(invocation(one_or_two_way))({ :via, :global, unquote(service_name(options)) }, unquote(request))
    end
  end

  defp invocation(:one_way), do: :cast
  defp invocation(:two_way), do: :call

  @doc false
  def generate_handle_call(options, { one_or_two_way, call, _body}) do
    request  = call_signature(call, options)
    api_call = api_signature(options, call)
    state_var = { state_name(options), [], nil }

    call_or_cast(one_or_two_way, request, state_var, api_call)
  end

  defp call_or_cast(:one_way, request, state_var, api_call) do
    quote do
      def handle_cast(unquote(request), șțąțɇ) do
        unquote(state_var) = șțąțɇ
        new_state = __MODULE__.Implementation.unquote(api_call)
        { :noreply, new_state }
        # |> Common.create_genserver_response(unquote(state_var))
      end
    end
  end

  defp call_or_cast(:two_way, request, state_var, api_call) do
    quote do
      def handle_call(unquote(request), _, șțąțɇ) do
        unquote(state_var) = șțąțɇ
        __MODULE__.Implementation.unquote(api_call)
        |> Common.create_genserver_response(șțąțɇ)
      end
    end
  end

  @doc false
  def generate_implementation(options, {_one_or_two_way, call, do: body}) do
    fix_warning = quote do
      _ = var!(unquote({ state_name(options), [], Elixir }))
      unquote(body)
    end

    quote do
      def(unquote(api_signature(options, call)), do: unquote(fix_warning))
    end
  end

  # only used for pools
  @doc false
  def generate_delegator(_options, {_one_or_two_way, _call, _body}), do: nil


  # given def fred(a, b) return { :fred, a, b } (in quoted form)
  @doc false
  def call_signature({ name, _, args }, options) do
    no_state_args = args_without_state_or_defaults(args, options)
    { :{}, [], [ name |  no_state_args ] }
  end

  # given def fred(a, b) return def fred(«state name», a, b)

  @doc false
  def api_signature(options, { name, context, args }) do
    no_state_args = args_without_state_or_defaults(args, options)

    { name, context, [ { state_name(options), [], nil } | no_state_args ] }
  end

  def args_without_state(args, options) do
    state_name = state_name(options)
    args
    |> Enum.reject(fn { name, _, _ } -> name == state_name end)
    |> Enum.map(fn name -> var!(name) end)
  end

  def args_without_state_or_defaults(args, options) do
    args_without_state(args, options)
    |> remove_any_default_values()
  end

  defp remove_any_default_values(args) do
    args
    |> Enum.map(&remove_one_default/1)
  end

  defp remove_one_default({ :\\, _, [ arg, _val ]}) do
    arg
  end

  defp remove_one_default(arg) do
    arg
  end



  @doc false
  def service_name(options) do
    options[:service_name] || quote(do: __MODULE__)
  end

  @doc false
  def state_name(options) do
    check_state_name(options[:state_name])
  end

  defp check_state_name(nil), do: :state
  defp check_state_name(name) when is_atom(name), do: name
  defp check_state_name({name, _, _}) do
    raise CompileError, description: "state_name: “#{name}” should be an atom, not a variable"
  end
  defp check_state_name(name) do
    raise CompileError, description: "state_name: “#{inspect name}” should be an atom"
  end
end
