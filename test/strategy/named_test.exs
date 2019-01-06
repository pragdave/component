defmodule Test.Strategy.Dynamic do

  use ExUnit.Case

  alias __MODULE__.Counter, as: NC

  # NOTE: because each test is run in its own process, we have to
  # initialize the component in each, as it is linked to the process
  # that initializes it. In a real application, you'll only initialize
  # it once.

  test "sanity check" do
    NC.initialize()
    c = NC.create
    assert NC.get_count(c) == 0
    NC.increment(c, 7)
    assert NC.get_count(c) == 7
    NC.destroy(c)
  end

  test "passing initial state" do
    NC.initialize()
    c = NC.create(10)
    assert NC.get_count(c) == 10
    NC.increment(c, 7)
    assert NC.get_count(c) == 17
    NC.destroy(c)
  end

  test "update and return" do
    NC.initialize()
    c = NC.create(2)
    assert NC.update_and_return(c, 5) == 7
    assert NC.get_count(c) == 7
    NC.destroy(c)
  end

  test "return current and update" do
    NC.initialize()
    c = NC.create(2)
    assert NC.return_current_and_update(c, 5) == 2
    assert NC.get_count(c) == 7
    NC.destroy(c)
  end

  test "multiple servers" do
    NC.initialize()
    c1 = NC.create()
    c2 = NC.create(99)
    assert NC.get_count(c1) == 0
    assert NC.get_count(c2) == 99
    NC.increment(c1, 7)
    NC.increment(c2, -7)
    assert NC.get_count(c1) == 7
    assert NC.get_count(c2) == 92
    NC.destroy(c1)
    NC.destroy(c2)
  end


  defmodule Counter do

    use Component.Strategy.Dynamic,
        initial_state: 0,
        state_name: :tally,
        show_code:  false


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
end
