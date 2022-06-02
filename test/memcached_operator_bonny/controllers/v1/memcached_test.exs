defmodule MemcachedOperatorBonny.Controller.V1.MemcachedTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias MemcachedOperatorBonny.Controller.V1.Memcached

  describe "add/1" do
    test "returns :ok" do
      event = %{}
      result = Memcached.add(event)
      assert result == :ok
    end
  end

  describe "modify/1" do
    test "returns :ok" do
      event = %{}
      result = Memcached.modify(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = %{}
      result = Memcached.delete(event)
      assert result == :ok
    end
  end

  describe "reconcile/1" do
    test "returns :ok" do
      event = %{}
      result = Memcached.reconcile(event)
      assert result == :ok
    end
  end
end
