defmodule MiniSymphonyTest do
  use ExUnit.Case
  doctest MiniSymphony

  test "greets the world" do
    assert MiniSymphony.hello() == :world
  end
end
