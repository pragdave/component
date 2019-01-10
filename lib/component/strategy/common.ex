defmodule Component.Strategy.Common do


  alias Component.Strategy.PreprocessorState, as: PS

  @moduledoc false

  @doc """
  Defines a worker function that simply updates the state. It will
  be run asynchronously (using `GenServer.cast`).

  The return value of the function becomes the new state.

  ~~~ elixir
  defmodule Dictionary do
    use Component.Strategy.Global,
        state_name: :dictionary,
        initial_state: %{}

    one_way add_key_value(key, value) do
      dictionary |> Map.put(key, value)
    end
  end
  ~~~
  """

  defmacro one_way(call, body) do
    n_way_implementation(:one_way, __CALLER__.module, call, body)
  end

  @doc """
  Defines a worker function that returns a value and potentially updates
  state.

  To simply return a value and leave the state unchanged, just have
  the function return that value:

  ~~~ elixir
  two_way get_state() do
    state
  end
  ~~~

  To set the state and return that state as a value, use
  `set_state_and_return`:

  ~~~ elixir
  two_way increment() do
    set_state_and_return(count + 1)
  end
  ~~~

  To set the state to one value and return another, use `set_state`
  passing it the new state as the first parameter and a block that
  determines the return value as the second:

  ~~~ elixir
  two_way get_count_then_increment() do
    set_state(count + 1) do     # this is the new state
      count                     # this will be the original value
    end
  end

  """
  defmacro two_way(call, body) do
    n_way_implementation(:two_way, __CALLER__.module, call, body)
  end

  defp n_way_implementation(one_or_two, caller, call, body) do
    PS.add_function(caller, { one_or_two, call, body })
    nil
  end

  @doc """
  Used at the end of a service function to indicate that
  the state should be updated and this new state value should also be
  returned as the value of the funcrtion.

  def increment(value) do
    set_state_and_return(count + value)
  end


  With no do: block, returns the new state as the reply value.
  """

  defmacro set_state_and_return(new_state) do
    quote bind_quoted: [ state: new_state ] do
      { :reply, state, state }
    end
  end

  @doc """
  Used at the end of a service function to indicate that
  the state should be updated, and to provide a return value. The
  new state is passed as a parameter, and a `do` block is
  evaluated to provide the return value.

  ~~~ elixir
  def put(key, value) do
    set_state(Map.put(dictionary, key, value)) do
      value
    end
  end
  ~~~
  """


  defmacro set_state(new_state, do: return) do
    quote do
      { :reply, unquote(return), unquote(new_state) }
    end
  end

  @doc """
  The functions in a `callbacks` block are injected into the genserver,
  and so can be used for things such as `init/1` or `handle_info/2`.
  """

  defmacro callbacks(do: callback_code) do
    PS.add_callbacks(__CALLER__.module, callback_code)
  end

  # # The strategy is the module (Global, Dynamic, Pooled)


  @doc false
#   def generate_code(caller, strategy) do

# #X#    { options, apis, handlers, implementations, _delegators } =
# #X#      create_functions_from_originals(caller, strategy)

#     callbacks = PS.get_callbacks(caller)

#     PS.stop(caller)

#     application = maybe_create_application(options)

#     quote do
#       use GenServer

#       unquote(application)

#       defoverridable(init: 1)

#       unquote(callbacks)

#       unquote_splicing(apis)
#       unquote_splicing(handlers)
#       defmodule Implementation do
#         unquote_splicing(implementations)
#       end
#     end
#     |> maybe_show_generated_code(options)
#   end

  @doc false


  def maybe_create_application(options) do
    if options[:top_level] do
      quote do
        use Application
        def start(_type, _args) do
          children = [ %{
            id:     __MODULE__.Id,
            start: { __MODULE__, :wrapped_create, [] }
           }]
          opts = [strategy: :one_for_one, name: __MODULE__.Supervisor]
          IO.inspect Supervisor.start_link(children, opts)
        end
      end
    else
      nil
    end
  end

  @doc !"public only for testing"
  def create_genserver_response(response = {:reply, _, _}, _state) do
    response
  end

  @doc false
  def create_genserver_response(result, state) do
    { :reply, result, state }
  end



  @doc """
  The create call accepts an optional state. A component can also have a
  default state.

  The component's default state can be a value or a function.

  There are 4 possibilities

  | default | override  | value used as initial state
  |---------|-----------|-------
  | val     |  none     | val
  | func    |  none     | func(nil)
  | val     |  override | override
  | func    |  override | func(override)

  """

  defmodule CommonAttribute do
    def no_overrides do
      :__flag_to_say_no_state_was_passed_to_create__
    end
  end

  @no_overrides CommonAttribute.no_overrides

  def derive_state(@no_overrides, default_state)
  when is_function(default_state)
  do
    default_state.(nil)
  end

  def derive_state(overrides, default_state)
  when is_function(default_state)
  do
    default_state.(overrides)
  end

  def derive_state(@no_overrides, default_state) do
    default_state
  end

  def derive_state(overrides, _default_state) do
    overrides
  end


end
