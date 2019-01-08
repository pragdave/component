defmodule FourOhFour do

  use Component.Strategy.Dynamic,
      state_name: :history,
      initial_state: %{}

  one_way record_404(history, user, url) do
    Map.update(history, user, [ url ], &[ url | &1 ])
  end

  two_way for_user(history, user) do
    Map.get(history, user, [])
  end
end
