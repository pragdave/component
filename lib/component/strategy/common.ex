defmodule Component.Strategy.Common do
  alias Component.Strategy.PreprocessorState, as: PS

  @moduledoc """
  Code in here is called from the target module, either at compile time
  (with things such as `one_way`) or at runtime (for example with
  `set_state`). There are also a few functions called by code that
  we generate (such as `create_genserver_response`)
  """

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
    PS.add_function(caller, {one_or_two, call, body})
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
    quote bind_quoted: [state: new_state] do
      {:reply, state, state}
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
      {:reply, unquote(return), unquote(new_state)}
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

  @doc !"public only for testing"
  def create_genserver_response(response = {:reply, _, _}, _state) do
    response
  end

  @doc false
  def create_genserver_response(result, state) do
    {:reply, result, state}
  end



  defmodule CommonAttribute do
    @moduledoc """
    Some "global" constants.
    """
    def no_overrides do
      :__flag_to_say_no_state_was_passed_to_create__
    end
  end

  @no_overrides CommonAttribute.no_overrides()

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
  def derive_state(@no_overrides, default_state)
      when is_function(default_state) do
    default_state.(nil)
  end

  def derive_state(overrides, default_state)
      when is_function(default_state) do
    default_state.(overrides)
  end

  def derive_state(@no_overrides, default_state) do
    default_state
  end

  def derive_state(overrides, _default_state) do
    overrides
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
    raise CompileError, description: "state_name: “#{inspect(name)}” should be an atom"
  end

  @doc """
  Forwards the contents of a stream either into a collectable or into a
  function. If the target is a list or map, the stream is reified at
  this point by calling `Enum.into`. In the latter case the function is
  with each value in turn. (It you need that function to have more
  context, simply create that context as a closure.P
  """

  def forward_stream(_result, :stream, when_done_callback)
   when is_function(when_done_callback) do
     raise """
     You can't have a when_done callback when returning a stream from a
     Hungry.consumer, because the library can't determine what 'done'
     means.
     """
  end

  def forward_stream(result, :stream, _when_done_callback) do
    result
  end

  # TODO: find a better way to make this properly asynchronous
  # (Stream.run suspends until the stream is fully processed, hence the
  # spawn.)

  def forward_stream(result, func, when_done_callback)
  when is_function(func) do
    stream = Stream.each(result, func)
    spawn_link(fn ->
      Stream.run(stream);
      if when_done_callback, do: when_done_callback.(result)
   end)
  end

  def forward_stream(result, collectable, when_done_callback)
  when is_list(collectable) or is_map(collectable) do
    return_value = Enum.into(result, collectable)
    if when_done_callback, do: when_done_callback.(result)
    return_value
  end

  def forward_stream(result, collectable, _when_done_callback) do
    Stream.into(result, collectable)
  end

end
