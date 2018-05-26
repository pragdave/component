defmodule Component.Strategy.Common do

  alias Component.Strategy.PreprocessorState, as: PS



  @doc """
  We replace the regular def with something that records the definition in
  a list. No code is emitted here—that happens in the before_compile hook
  """

  defmacro one_way(call, body) do
    n_way_implementation(:one_way, __CALLER__.module, call, body)
  end


  defmacro two_way(call, body) do
    n_way_implementation(:two_way, __CALLER__.module, call, body)
  end

  defp n_way_implementation(one_or_two, caller, call, body) do
    PS.add_function(caller, { one_or_two, call, body })
    nil
  end

  # @doc """
  # Used at the end of a service function to indicate that
  # the state should be updated, and to provide a return value. The
  # new state is passed as a parameter, and a `do` block is
  # evaluated to provide the return value.

  # If not called in a service function, then the return value of the
  # function will be the value returned to the client, and the state
  # will not be updated.

  #     def put(store, key, value) do
  #       set_state(Map.put(store, key, value)) do
  #         value
  #       end
  #     end


  # With no do: block, returns the new state as the reply value.
  # """

  defmacro set_state_and_return(new_state) do
    quote bind_quoted: [ state: new_state ] do
      { :reply, state, state }
    end
  end


  defmacro set_state(new_state, do: return) do
    quote do
      { :reply, unquote(return), unquote(new_state) }
    end
  end


  # # The strategy is the module (Anonymous, Named, Pooled)

  @doc false


  @doc false
  def generate_code(caller, strategy) do

    { options, apis, handlers, implementations, _delegators } =
      create_functions_from_originals(caller, strategy)

    PS.stop(caller)

    quote do
      use GenServer

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
