defmodule Component.Strategy.PreprocessorState do

  defstruct(
    functions:  [],     # the list of { call, body }s from each def
    options:    []      # the options from `use`
   )


  def start_link(name, options) do
    { :ok, pid } = Agent.start_link(
      fn ->
        %__MODULE__{options: options}
      end,
      name: name_for(name)
    )
    pid
  end


  def stop(name) do
    Agent.stop(name_for(name))
  end

  def options(name) do
    Agent.get(name_for(name), &(&1.options))
  end

  def add_function(name, func) do
    Agent.update(name_for(name), fn state ->
      %{ state | functions: [ func | state.functions ] }
    end)
  end

  def function_list(name) do
    Agent.get(name_for(name), &(&1.functions))
  end

  # only for testing
  def name_for(name), do: :"-- pragdave.me.preprocessor.state.#{name} --"
end
