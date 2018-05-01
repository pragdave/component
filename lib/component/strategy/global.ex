defmodule Component.Strategy.Global do

  @moduledoc """
  Implement a singleton (global) named service.

  ### Usage

  To create the service:

  * Create a module that implements the API you want. This API will be
    expressed as a set of public functions. Each function will automatically
    receive the current state in a variable (by default named `state`). There is
    not need to declare this as a
     parameter.[<small><small>[why?]</small></small>](background.html#why-magic-state).
    If a function wants to change the state, it must end with a call to the
    `Jeeves.Common.update_state/2` function (which will have been
    imported into your module automatically).

    For this example, we'll call the module `NamedService`.

  * Add the line `use Jeeves.Named` to the top of this module.

  To consume the service:

  * Create an instance of the service with `NamedJeeves.run()`. You can pass
    initial state to the service as an optional parameter. This call returns
    a handle to this service instance, but you shouldn't use it.

  * Call the API functions in the service.


  ### Example

      defmodule KV do
        using Jeeves.Named, state: %{}

        def get(name), do: state[name]
        def put(name, value) do
          update_state(Map.put(state, name, value)) do
            value
          end
        end
      end

      KV.run(%{ name: "Elixir" })
      KV.put(:type, "language")
      KV.get(:name)    # => "Elixir"
      KV.get(:type)    # => "language"


  ### Options

  You can pass a keyword list to `use Jeeves.Anonymous:`

  * `state:` _value_

  * `state_name:` _atom_

    The default name for the state variable is (unimaginatively)  `state`.
    Use `state_name` to override this. For example, you could change the
    previous example to use `store` for the state with:

        defmodule KV do
          using Jeeves.Named, state: %{}, state_name: :store

          def get(name), do: store[name]
          def put(name, value) do
            update_state(Map.put(store, name, value)) do
              value
            end
          end
        end

  * `service_name:` _atom_

    The default name for the service is the name of the module that defines it.
    Use `service_name:` to change this.

  * `showcode:` _boolean_

    If truthy, dump a representation of the generated code to STDOUT during
    compilation.

  """


  alias   Component.Strategy.Common
  require Common

  @doc false
  defmacro __using__(opts \\ []) do

    Common.generate_common_code(
      __CALLER__.module,
      __MODULE__,
      opts,
      service_name(opts))
  end

  @doc false
  defmacro generate_code_callback(_) do
    Common.generate_code(__CALLER__.module, __MODULE__)
  end

  @doc false
  def generate_api_call(options, {one_or_two_way, call, _body}) do
    quote do
      def(unquote(call), do: unquote(api_body(one_or_two_way, options, call)))
    end
  end

  @doc false
  defp api_body(one_or_two_way, options, call) do
    request = call_signature(call)
    quote do
      GenServer.unquote(invocation(one_or_two_way))({ :via, :global, unquote(service_name(options)) }, unquote(request))
    end
  end

  defp invocation(:one_way), do: :cast
  defp invocation(:two_way), do: :call

  @doc false
  def generate_handle_call(options, { one_or_two_way, call, _body}) do
    request  = call_signature(call)
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
  def generate_implementation(options, {_one_or_two_way, call, body}) do
    quote do
      def(unquote(api_signature(options, call)), unquote(body))
    end
  end

  # only used for pools
  @doc false
  def generate_delegator(_options, {_one_or_two_way, _call, _body}), do: nil


  # given def fred(a, b) return { :fred, a, b }
  @doc false
  def call_signature({ name, _, args }) do
    no_state_args = args
                    |> Enum.reject(fn { name, _, _ } -> name == :state end)
                    |> Enum.map(fn name -> var!(name) end)

    { :{}, [], [ name |  no_state_args ] }
  end

  # given def fred(a, b) return def fred(«state name», a, b)

  @doc false
  def api_signature(options, { name, context, args }) do
    { name, context, [ { state_name(options), [], nil } | args ] }
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
