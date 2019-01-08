defmodule Test.Strategy.Pooled do
  use ExUnit.Case

  @pi __MODULE__.CounterImplicit
  @pe __MODULE__.CounterExplicit

  # NOTE: because each test is run in its own process, we have to
  # initialize the component in each, as it is linked to the process
  # that initializes it. In a real application, you'll only initialize
  # it once.

  test "sum of calls (implicit)" do
    @pi.initialize()
    c1 = @pi.create()
    c2 = @pi.create()
    @pi.increment(c1)
    assert_sum_implicit(c1, c2, 1)
    @pi.increment(c2)
    assert_sum_implicit(c1, c2, 2)
    @pi.increment(c2)
    assert_sum_implicit(c1, c2, 3)

    # free off one of the pool workers, and then get it back
    @pi.destroy(c1)
    c1 = @pi.create()

    # state should be retained
    assert_sum_implicit(c1, c2, 3)
  end

  defp assert_sum_implicit(c1, c2, value) do
    assert @pi.get_count(c1) + @pi.get_count(c2) == value
  end

  test "sum of calls (explicit)" do
    @pe.initialize()
    c1 = @pe.create()
    c2 = @pe.create()
    @pe.increment(c1)
    assert_sum_explicit(c1, c2, 1)
    @pe.increment(c2)
    assert_sum_explicit(c1, c2, 2)
    @pe.increment(c2)
    assert_sum_explicit(c1, c2, 3)

    # free off one of the pool workers, and then get it back
    @pe.destroy(c1)
    c1 = @pe.create()

    # state should be retained
    assert_sum_explicit(c1, c2, 3)
  end

  defp assert_sum_explicit(c1, c2, value) do
    assert @pe.get_count(c1) + @pe.get_count(c2) == value
  end


  defmodule CounterImplicit do
    use Component.Strategy.Pooled,
      pool: [min: 2, max: 2],
      state_name: :call_count,
      initial_state: 0

    one_way increment() do
      call_count + 1
    end

    # fetch
    two_way get_count() do
      call_count
    end
  end

  defmodule CounterExplicit do
    use Component.Strategy.Pooled,
      pool: [min: 2, max: 2],
      state_name: :call_count,
      initial_state: 0,
      show_code: false

    one_way increment(call_count) do
      call_count + 1
    end

    # fetch
    two_way get_count(call_count) do
      call_count
    end
  end
end
