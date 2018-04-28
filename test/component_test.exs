defmodule ComponentTest do
  use ExUnit.Case
  doctest Component

  test "greets the world" do
    assert Component.hello() == :world
  end
end
