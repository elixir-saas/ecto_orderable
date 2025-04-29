defmodule EctoOrderableTest do
  use EctoOrderable.RepoCase

  setup do
    {:ok, set} = TestRepo.insert(%Set{})

    items =
      for i <- 0..10 do
        TestRepo.insert!(%Item{set: set, order_index: i * 1000.0})
      end

    %{set: set, items: items}
  end

  test "finds the first order", %{set: set} do
    assert 0.0 == EctoOrderable.first_order(TestOrder.set(set))
  end

  test "finds the last order", %{set: set} do
    assert 10000.0 == EctoOrderable.last_order(TestOrder.set(set))
  end

  test "finds the next order", %{set: set} do
    assert 11000.0 == EctoOrderable.next_order(TestOrder.set(set))
  end
end
