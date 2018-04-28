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

  # so I can test
  def n_way_implementation(one_or_two, caller, call, body) do
    PS.add_function(caller, { one_or_two, call, body })
    nil
  end

  def ok([result: _result, state: _state]) do
    raise "ok"
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

  # defmacro set_state(new_state) do
  #   quote bind_quoted: [ state: new_state ] do
  #     { :reply, state, state }
  #   end
  # end


  # defmacro set_state(new_state, do: return) do
  #   quote do
  #     { :reply, unquote(return), unquote(new_state) }
  #   end
  # end


  # # The strategy is the module (Anonymous, Named, Pooled)

  @doc false
  def generate_common_code(caller, strategy, opts, name) do
    PS.start_link(caller, opts)

    default_state = Keyword.get(opts, :initial_state, :no_state)
    server_opts = if name do [ name: name ] else [ ] end

    quote do
      #import Kernel,        except: [ def: 2 ]
      #import Jeeves.Common, only:   [ def: 2, set_state: 1, set_state: 2 ]

      import Component.Strategy.Common,
             only: [ ok: 1, one_way: 2, two_way: 2 ]

      @before_compile { unquote(strategy), :generate_code_callback }

      def run() do
        run(unquote(default_state))
      end

      def run(state_override) do
        state = initial_state(state_override, unquote(default_state))
        { :ok, pid } = GenServer.start_link(__MODULE__, state, server_opts())
        pid
      end

      def start_link(state_override) do
        { :ok, run(state_override) }
      end

      def init(state) do
        { :ok, state }
      end

      def initial_state(override, _default) do
        override
      end

      def server_opts() do
        unquote(server_opts)
      end

      defoverridable [ initial_state: 2, init: 1 ]
    end
    |> maybe_show_generated_code(opts)
  end

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
  def create_genserver_response(response, state) do
    { :reply, response, state }
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
