defmodule Component.Strategy.PreprocessorState do
  defstruct(
    # the strategy module (Global, Dynamic, ...)
    strategy: nil,
    # the list of { call, body }s from each def
    functions: [],
    # the options from `use`
    options: [],
    # callbacks to inject into the genserver
    callbacks: nil
  )

  def start_link(name, strategy, options) do
    agent_name = name_for(name)

    # I don't know what's happening, but compiling under
    # Visual Studio Code seems to start the agent twice.

    Agent.start_link(
      fn ->
        %__MODULE__{
          options: options,
          strategy: strategy
        }
      end,
      name: agent_name
    )
    |> case do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        pid
    end
  end

  def stop(name) do
    Agent.stop(name_for(name))
  end

  def options(name) do
    Agent.get(name_for(name), & &1.options)
  end

  @spec strategy_and_options(module_name :: atom) :: {strategy_module :: atom, options :: Map.t()}
  def strategy_and_options(name) do
    Agent.get(name_for(name), &{&1.strategy, &1.options})
  end

  def add_function(name, func) do
    :ok =
      Agent.update(name_for(name), fn state ->
        %{state | functions: [func | state.functions]}
      end)
  end

  def add_callbacks(name, callbacks) do
    Agent.update(name_for(name), fn state ->
      %{state | callbacks: callbacks}
    end)
  end

  def get_callbacks(name) do
    Agent.get(name_for(name), & &1.callbacks)
  end

  def function_list(name) do
    Agent.get(name_for(name), & &1.functions)
  end

  # only for testing
  def name_for(name), do: :"-- pragdave.me.preprocessor.state.#{name} --"
end
