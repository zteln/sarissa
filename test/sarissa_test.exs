defmodule SarissaTest do
  use ExUnit.Case
  doctest Sarissa

  test "greets the world" do
    assert Sarissa.hello() == :world
  end
end
