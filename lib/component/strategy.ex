defmodule Component.Strategy do

  alias   Component.Strategy.PreprocessorState, as: PS

  @moduledoc """
  The strategy-specific stuff is implemented in submodules
  (Strategy.Global and so on). They must provide this API
  """

  @type  quoted_code :: atom
                      | integer
                      | float
                      | List.t
                      | String.t
                      | tuple()

  @type  options     :: Map.t
  @type  original_fn :: quoted_code

  @callback generate_api_call(options, original_fn) :: quoted_code
  @callback generate_handle_call(options, original_fn) :: quoted_code
  @callback generate_implementation(options, original_fn) :: quoted_code
  @callback generate_delegator(options, original_fn) :: quoted_code
  @callback emit_code(functions :: map, target_module :: atom, options ) :: quoted_code

  def handle_using(options_from_using, target_module, strategy) do
    options = parse_options(options_from_using, target_module, strategy)
    PS.start_link(target_module, strategy, options)

    generated_code = quote do
      import Component.Strategy.Common, only: [
        callbacks: 1,
        one_way: 2,
        two_way: 2,
        set_state_and_return: 1,
        set_state: 2
      ]

      @before_compile { unquote(__MODULE__), :generate_code_callback }
      @after_compile  { unquote(__MODULE__), :stop_preprocessor_state_callback }
    end
  end


  defp parse_options(options_from_using, target_module, strategy) do
    %{
      initial_state:  Keyword.get(options_from_using, :initial_state, :no_initial_state),
      state_name:     Keyword.get(options_from_using, :state_name,    :state),
      show_code:      Keyword.get(options_from_using, :show_code,     false),
    }
    |> strategy.parse_options(options_from_using, target_module)
  end


 #########################################################################
 # Callbacks from the target module. The first does the code generation  #
 # for the one_way and two_way functions. The second, called after the   #
 # target is compiled, simply kills the PreprocessStatus agent, which    #
 # was used to accumulate the functions.                                 #
 #########################################################################


  defmacro generate_code_callback(env) do
    { strategy, options } = PS.strategy_and_options(env.module)
    generate_code(strategy, env.module, options)
  end

  defmacro stop_preprocessor_state_callback(env, _bytecode) do
    PS.stop(env.module)
  end



  @doc """
  Orchestrate the production of code for a particular strategy. We're
  called after the target module has been parsed but before compilation.
  All tne one-way and two-way declarations have been tucked away in the
  preprocessor state: we extract them and get the individual strategies
  to generate code.
  """
  defp generate_code(strategy, target_module, options) do
    functions = gather_code_and_metadata(target_module, strategy)
    strategy.emit_code(functions, target_module, options)
    |> maybe_show_generated_code(options)
  end


  defp gather_code_and_metadata(target_module, strategy) do
    initial_state = %{
      options:   PS.options(target_module),
      callbacks: PS.get_callbacks(target_module),
      apis:      [],
      handlers:  [],
      implementations: [],
      delegators:      [],
    }

    PS.function_list(target_module)
    |> Enum.reduce(initial_state, &generate_functions(strategy, &1, &2))
  end


  @doc !"public only for testing"
  defp generate_functions(
    strategy,
    original_fn,
    generated_functions
  )
    do
      options = generated_functions.options

      generated_functions
      |> add_a_function(:apis,            strategy.generate_api_call(options, original_fn))
      |> add_a_function(:handlers,        strategy.generate_handle_call(options, original_fn))
      |> add_a_function(:implementations, strategy.generate_implementation(options, original_fn))
      |> add_a_function(:delegators,      strategy.generate_delegator(options, original_fn))
  end

  defp add_a_function(generated_functions, key, new_function) do
    update_in(generated_functions, [key], &[ new_function | &1 ])
  end


   @doc false
   defp maybe_show_generated_code(code, opts) do
    IO.inspect show_code: code
    if opts.show_code do
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

  @doc """
  If this component is top-level, generate the application stuff.
  """
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

end
