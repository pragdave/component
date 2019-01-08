defmodule Test.Strategy.Global do
  use ExUnit.Case

  for {type, module} <- [
        implicit: __MODULE__.GlobalCounterImplicitState,
        explicit: __MODULE__.GlobalCounterExplicitState
      ] do

    @gc module

    test "sanity check (#{type})" do
      @gc.create
      assert @gc.get_count == 0
      @gc.increment(7)
      assert @gc.get_count == 7
      @gc.destroy
    end

    test "passing initial state (#{type})" do
      @gc.create(10)
      assert @gc.get_count == 10
      @gc.increment(7)
      assert @gc.get_count == 17
      @gc.destroy
    end

    test "update and return (#{type})" do
      @gc.create(2)
      assert @gc.update_and_return(5) == 7
      assert @gc.get_count() == 7
      @gc.destroy
    end

    test "return current and update (#{type})" do
      @gc.create(2)
      assert @gc.return_current_and_update(5) == 2
      assert @gc.get_count() == 7
      @gc.destroy
    end
  end

  defmodule GlobalCounterImplicitState do
    use Component.Strategy.Global,
      initial_state: 0,
      show_code: false,
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

  defmodule GlobalCounterExplicitState do
    use Component.Strategy.Global,
      initial_state: 0,
      show_code: false,
      state_name: :tally

    one_way increment(tally, n) do
      tally + n
    end

    # fetch
    two_way get_count(tally) do
      tally
    end

    # update and fetch
    two_way update_and_return(tally, n) do
      set_state_and_return(tally + n)
    end

    # fetch and update
    two_way return_current_and_update(tally, n) do
      set_state(tally + n) do
        tally
      end
    end
  end
end
