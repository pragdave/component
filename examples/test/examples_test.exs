defmodule ExamplesTest do
  use ExUnit.Case
  doctest Examples

  test "greets the world" do
    assert Examples.hello() == :world
  end
end
