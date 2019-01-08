defmodule Test.Strategy.Dynamic do
  use ExUnit.Case


  # NOTE: because each test is run in its own process, we have to
  # initialize the component in each, as it is linked to the process
  # that initializes it. In a real application, you'll only initialize
  # it once.

  for {type, module} <- [
        implicit: __MODULE__.CounterImplicit,
        explicit: __MODULE__.CounterExplicit
      ] do
    @nc module

    test "sanity check (#{type})" do
      @nc.initialize()
      c = @nc.create
      assert @nc.get_count(c) == 0
      @nc.increment(c, 7)
      assert @nc.get_count(c) == 7
      @nc.destroy(c)
    end

    test "passing initial state (#{type})" do
      @nc.initialize()
      c = @nc.create(10)
      assert @nc.get_count(c) == 10
      @nc.increment(c, 7)
      assert @nc.get_count(c) == 17
      @nc.destroy(c)
    end

    test "update and return (#{type})" do
      @nc.initialize()
      c = @nc.create(2)
      assert @nc.update_and_return(c, 5) == 7
      assert @nc.get_count(c) == 7
      @nc.destroy(c)
    end

    test "return current and update (#{type})" do
      @nc.initialize()
      c = @nc.create(2)
      assert @nc.return_current_and_update(c, 5) == 2
      assert @nc.get_count(c) == 7
      @nc.destroy(c)
    end

    test "multiple servers (#{type})" do
      @nc.initialize()
      c1 = @nc.create()
      c2 = @nc.create(99)
      assert @nc.get_count(c1) == 0
      assert @nc.get_count(c2) == 99
      @nc.increment(c1, 7)
      @nc.increment(c2, -7)
      assert @nc.get_count(c1) == 7
      assert @nc.get_count(c2) == 92
      @nc.destroy(c1)
      @nc.destroy(c2)
    end
  end

  defmodule CounterImplicit do
    use Component.Strategy.Dynamic,
      initial_state: 0,
      state_name: :tally,
      show_code: false

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

  defmodule CounterExplicit do
    use Component.Strategy.Dynamic,
      initial_state: 0,
      state_name: :tally,
      show_code: false

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
