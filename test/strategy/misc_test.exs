defmodule Test.Strategy.Misc do
  use ExUnit.Case

  defmodule Random do

    use Component.Strategy.Global,
        initial_state: 0,
        show_code:     false,
        state_name:    :my_state

    # the code always injects a state variable, even if it isn't used.
    # This used to generate a compiler warning. This isn't really a
    # test per-se: it just generates a warning when running the
    # tests. You shouldn't see the warning post 1/3/2019

    one_way doesnt_use_state() do
      99
    end
  end

  test "doesn't generate warning" do
    assert true
  end
end
