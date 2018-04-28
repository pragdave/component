defmodule Examples.GlobalCounter do

  use Component.Strategy.Named,
      initial_state: 0,
      show_code: 1,
      state_name: :tally


  one_way increment(n) do
    ok(state: tally + n)
  end

  # fetch
  two_way get_count() do
    ok(result: tally)
  end

#   # update and fetch
#   two_way update_and_return(state, n) do
#     state = state + 1
#     ok(result: state, state: state)
#   end

#   # fetch and update
#   two_way return_current_and_update(state, n) do
#     ok(result: state, state: state + 1)
#   end


# end

# defmodule GlobalCounter do

#   def increment(n \\ 1) do
#     GenServer.cast(GlobalCounter, { :increment, n })
#   end

#   def get_count() do
#     GenServer.call(GlobalCounter, { :get_count })
#   end

#   defmodule Server do
#     use GenServer

#     def start_link(args) do
#       GenServer.start_link(__MODULE__, args, name: { :via, Swarm, GlobalCounter })
#     end

#     def init(state) do
#       { :ok, state }
#     end

#     def handle_cast({:increment, n}, state) do
#       { :ok, new_state } = GlobalCounter.Impl.process(state, :increment, b)
#       { :noreply, new_state }
#     end

#     def handle_call({ :get_count }, _from, state) do
#       { :ok, result } = GlobalCounter.Impl.process(state, :get_count)
#       { :reply, result, state)
#     end
#   end

#   defmodule Impl do
#     # update
#     def process(state = %{ count }, :increment, n \\ 1) do
#       { :ok, %{ state: count: count + n }}
#     end

#     # fetch
#     def process(_state = %{ count }, :get_count) do
#       { :ok, count }
#     end

#   end
end
