defmodule MemcachedOperatorBonnyTest do
  use ExUnit.Case
  doctest MemcachedOperatorBonny

  test "greets the world" do
    assert MemcachedOperatorBonny.hello() == :world
  end
end
