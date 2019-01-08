defmodule Examples.GlobalCounter do

  use Component.Strategy.Global,
      initial_state: 0,
      show_code:     false,
      state_name:    :tally


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

Process.whereis(ExUnit.Server) || ExUnit.start

defmodule UseGlobal do

  use ExUnit.Case

  alias Examples.GlobalCounter, as: GC


  test "sanity check" do
    GC.create
    assert GC.get_count == 0
    GC.increment 7
    assert GC.get_count == 7
    GC.destroy
  end

  test "passing initial state" do
    GC.create(10)
    assert GC.get_count == 10
    GC.increment 7
    assert GC.get_count == 17
    GC.destroy
  end

  test "update and return" do
    GC.create(2)
    assert GC.update_and_return(5) == 7
    assert GC.get_count() == 7
    GC.destroy
  end

  test "return current and update" do
    GC.create(2)
    assert GC.return_current_and_update(5) == 2
    assert GC.get_count() == 7
    GC.destroy
  end
end
