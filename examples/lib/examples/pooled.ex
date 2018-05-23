defmodule Examples.PooledCounter do

  use Component.Strategy.Pooled,
      initial_state: 0,
      state_name: :tally


  one_way increment(n) do
    tally + n
  end

  # fetch
  two_way get_count() do
    tally
  end

  # update and fetch
  two_way update_and_return(n) do
    set_state_and_return(tally + n)
  end

  # fetch and update
  two_way return_current_and_update(n) do
    set_state(tally + n) do
      tally
    end
  end
end
