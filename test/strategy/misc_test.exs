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


  defmodule GlobalUsesDefaultParameter do
    use Component.Strategy.Global,
    initial_state: 0,
    show_code:     false,
    state_name:    :total

    one_way increment(param \\ 1) do
      total + param
    end

    two_way value() do
      total
    end
  end

  test "default parameters (global)" do
    GlobalUsesDefaultParameter.create
    assert GlobalUsesDefaultParameter.value == 0
    GlobalUsesDefaultParameter.increment
    assert GlobalUsesDefaultParameter.value == 1
    GlobalUsesDefaultParameter.increment(99)
    assert GlobalUsesDefaultParameter.value == 100
  end

  defmodule DynamicUsesDefaultParameter do
    use Component.Strategy.Dynamic,
    initial_state: 0,
    show_code:     false,
    state_name:    :total

    one_way increment(param \\ 1) do
      total + param
    end

    two_way value() do
      total
    end
  end

  test "default parameters (dynamic)" do
    DynamicUsesDefaultParameter.initialize
    udp = DynamicUsesDefaultParameter.create
    assert DynamicUsesDefaultParameter.value(udp) == 0
    DynamicUsesDefaultParameter.increment(udp)
    assert DynamicUsesDefaultParameter.value(udp) == 1
    DynamicUsesDefaultParameter.increment(udp, 99)
    assert DynamicUsesDefaultParameter.value(udp) == 100
  end

end
