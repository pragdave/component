defmodule Stack do

  use Component.Strategy.Global, initial_state: [], state_name: :stack, show_code: 1

  one_way push(value), do: [ value | stack ]

  two_way pop() do
    set_state(tl(stack)) do
      hd(stack)
    end
  end
end
