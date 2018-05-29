

defmodule Test.Strategy.Hungry do

  use ExUnit.Case

  alias __MODULE__.Adder, as: HA

  test "basic operation" do
    HA.initialize()
    assert HA.consume([1,2,"cat"]) == [ 3, 6, "catcat" ]
  end

  test "supports into" do
    HA.initialize()
    assert HA.consume(a: :b, c: :d) == [ b: :a, d: :c ]
  end

  test "schedules workers" do
    HA.initialize()
    assert HA.consume(1..100) == (1..100 |> Enum.map(&(&1*3)))
  end


  defmodule Adder do

    use Component.Strategy.Hungry,
        show_code:           false,
        default_concurrency: 5

    def process(val) when is_number(val) do
      val * 3
    end

    def process(val) when is_binary(val) do
      val <> val
    end

    def process({a, b}), do: { b, a }
  end

end
