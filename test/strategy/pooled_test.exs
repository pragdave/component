defmodule Test.Strategy.Pooled do

  use ExUnit.Case

  alias __MODULE__.Counter, as: PC

  # NOTE: because each test is run in its own process, we have to
  # initialize the component in each, as it is linked to the process
  # that initializes it. In a real application, you'll only initialize
  # it once.

  test "sum of calls" do
    PC.initialize()
    c1 = PC.create
    c2 = PC.create
    PC.increment(c1)
    assert_sum(c1, c2, 1)
    PC.increment(c2)
    assert_sum(c1, c2, 2)
    PC.increment(c2)
    assert_sum(c1, c2, 3)

    # free off one of the pool workers, and then get it back
    PC.destroy(c1)
    c1 = PC.create

    # state should be retained
    assert_sum(c1, c2, 3)
  end

  defp assert_sum(c1, c2, value) do
    assert PC.get_count(c1) + PC.get_count(c2) == value
  end


  defmodule Counter do

    use Component.Strategy.Pooled,
        pool:           [ min: 2, max: 2 ],
        state_name:     :call_count,
        initial_state:  0


    one_way increment() do
      call_count + 1
    end

    # fetch
    two_way get_count() do
      call_count
    end

  end
end
