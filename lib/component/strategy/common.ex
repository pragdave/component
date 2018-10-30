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


  # # The strategy is the module (Anonymous, Named, Pooled)


  @doc false
  def generate_code(caller, strategy) do

    { options, apis, handlers, implementations, _delegators } =
      create_functions_from_originals(caller, strategy)

    PS.stop(caller)

    application = maybe_create_application(options)
    quote do
      use GenServer

      unquote(application)

      unquote_splicing(apis)
      unquote_splicing(handlers)
      defmodule Implementation do
        unquote_splicing(implementations)
      end
    end
    |> maybe_show_generated_code(options)
  end

  @doc false
  def create_functions_from_originals(caller, strategy) do
    options = PS.options(caller)

    PS.function_list(caller)
    |> Enum.reduce({nil, [], [], [], []}, &generate_functions(strategy, options, &1, &2))
  end


  @doc !"public only for testing"
  def generate_functions(
    strategy,
    options,
    original_fn,
    {_, apis, handlers, impls, delegators}
  )
    do
    {
      options,
      [ strategy.generate_api_call(options, original_fn)       | apis       ],
      [ strategy.generate_handle_call(options, original_fn)    | handlers   ],
      [ strategy.generate_implementation(options, original_fn) | impls      ],
      [ strategy.generate_delegator(options, original_fn)      | delegators ]
    }
  end

  def maybe_create_application(options) do
    if options[:top_level] do
      quote do
        use Application
        def start(_type, _args) do
          children = [ %{
            id:     __MODULE__,
            start: { __MODULE__, :create, [] }
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

  @doc false
  def maybe_show_generated_code(code, opts) do
    if opts[:show_code] do
      IO.puts ""
      code
      |> Macro.to_string()
      |> String.replace(~r{^\w*\(}, "")
      |> String.replace(~r{\)\w*$}, "")
      |> String.replace(~r{def\((.*?)\)\)}, "def \\1)")
      |> IO.puts
    end
    code
  end
end
