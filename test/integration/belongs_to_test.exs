defmodule Integration.BelongsToTest do
  @moduledoc """
  Integration tests for belongs-to ordering.

  Tests the common use case where items belong to a parent record
  and are ordered within that parent's scope.

  Example: Todos belonging to a User, ordered per-user.
  """
  use EctoOrderable.RepoCase

  alias EctoOrderable.TestRepo, as: Repo

  setup do
    {:ok, set} = Repo.insert(%Schemas.Set{})

    items =
      for i <- 1..5 do
        Repo.insert!(%Schemas.Item{set: set, order_index: i * 1000.0})
      end

    %{set: set, items: items}
  end

  describe "scope resolution" do
    test "accepts parent struct", %{set: set} do
      assert TestOrder.first_order(set) == 1000.0
    end

    test "accepts item struct", %{items: [item | _]} do
      assert TestOrder.first_order(item) == 1000.0
    end

    test "accepts keyword list", %{set: set} do
      assert TestOrder.first_order(set_id: set.id) == 1000.0
    end
  end

  describe "first_order/1" do
    test "returns order of first item", %{set: set} do
      assert TestOrder.first_order(set) == 1000.0
    end

    test "returns 0.0 for empty set" do
      {:ok, empty_set} = Repo.insert(%Schemas.Set{})
      assert TestOrder.first_order(empty_set) == 0.0
    end
  end

  describe "last_order/1" do
    test "returns order of last item", %{set: set} do
      assert TestOrder.last_order(set) == 5000.0
    end

    test "returns 0.0 for empty set" do
      {:ok, empty_set} = Repo.insert(%Schemas.Set{})
      assert TestOrder.last_order(empty_set) == 0.0
    end
  end

  describe "next_order/1" do
    test "returns last_order + increment", %{set: set} do
      assert TestOrder.next_order(set) == 6000.0
    end

    test "returns increment for empty set" do
      {:ok, empty_set} = Repo.insert(%Schemas.Set{})
      assert TestOrder.next_order(empty_set) == 1000.0
    end
  end

  describe "count/1" do
    test "returns count of items in set", %{set: set} do
      assert TestOrder.count(set) == 5
    end

    test "returns 0 for empty set" do
      {:ok, empty_set} = Repo.insert(%Schemas.Set{})
      assert TestOrder.count(empty_set) == 0
    end
  end

  describe "siblings/1" do
    test "returns query for all items in set", %{set: set, items: items} do
      result = TestOrder.siblings(set) |> Repo.all()
      assert length(result) == length(items)
    end

    test "scopes correctly when multiple sets exist", %{set: set, items: items} do
      # Create another set with different items
      {:ok, other_set} = Repo.insert(%Schemas.Set{})
      Repo.insert!(%Schemas.Item{set: other_set, order_index: 1000.0})
      Repo.insert!(%Schemas.Item{set: other_set, order_index: 2000.0})

      # Original set should still have same count
      result = TestOrder.siblings(set) |> Repo.all()
      assert length(result) == length(items)

      # Other set should have its own items
      other_result = TestOrder.siblings(other_set) |> Repo.all()
      assert length(other_result) == 2
    end
  end

  describe "sibling_before/1" do
    test "returns item before", %{items: items} do
      [first, second | _] = items
      assert TestOrder.sibling_before(second).id == first.id
    end

    test "returns nil for first item", %{items: [first | _]} do
      assert TestOrder.sibling_before(first) == nil
    end
  end

  describe "sibling_after/1" do
    test "returns item after", %{items: items} do
      [first, second | _] = items
      assert TestOrder.sibling_after(first).id == second.id
    end

    test "returns nil for last item", %{items: items} do
      last = List.last(items)
      assert TestOrder.sibling_after(last) == nil
    end
  end

  describe "move/2 with direction: :up" do
    test "moves item up one position", %{items: items} do
      [first, second | _] = items
      result = TestOrder.move(second, direction: :up)

      # Should now be before first
      assert result.order_index < first.order_index
    end

    test "returns unchanged when already first", %{items: [first | _]} do
      result = TestOrder.move(first, direction: :up)
      assert result.order_index == first.order_index
    end

    test "places between previous two items", %{items: items} do
      [first, second, third | _] = items

      result = TestOrder.move(third, direction: :up)

      # Should be between first and second
      assert result.order_index > first.order_index
      assert result.order_index < second.order_index
    end
  end

  describe "move/2 with direction: :down" do
    test "moves item down one position", %{items: items} do
      [_first, _second, _third, fourth, fifth] = items
      result = TestOrder.move(fourth, direction: :down)

      # Should now be after fifth (last)
      assert result.order_index > fifth.order_index
    end

    test "returns unchanged when already last", %{items: items} do
      last = List.last(items)
      result = TestOrder.move(last, direction: :down)
      assert result.order_index == last.order_index
    end

    test "places between next two items", %{items: items} do
      [first, second, third | _] = items

      result = TestOrder.move(first, direction: :down)

      # Should be between second and third
      assert result.order_index > second.order_index
      assert result.order_index < third.order_index
    end
  end

  describe "move/2 with between" do
    test "moves between two items", %{items: items} do
      [first, second, _third, _fourth, fifth] = items

      result = TestOrder.move(fifth, between: {first.id, second.id})

      assert result.order_index > first.order_index
      assert result.order_index < second.order_index
    end

    test "moves to beginning with {nil, first_id}", %{items: items} do
      [first, _second, third | _] = items

      result = TestOrder.move(third, between: {nil, first.id})

      assert result.order_index < first.order_index
    end

    test "moves to end with {last_id, nil}", %{items: items} do
      [first | _] = items
      last = List.last(items)

      result = TestOrder.move(first, between: {last.id, nil})

      assert result.order_index > last.order_index
    end

    test "returns unchanged with {nil, nil} for only item" do
      {:ok, set} = Repo.insert(%Schemas.Set{})
      item = Repo.insert!(%Schemas.Item{set: set, order_index: 1000.0})

      result = TestOrder.move(item, between: {nil, nil})

      assert result.order_index == item.order_index
    end

    test "calculates midpoint correctly", %{items: items} do
      [first, second | _] = items
      last = List.last(items)

      result = TestOrder.move(last, between: {first.id, second.id})

      # Midpoint of 1000.0 and 2000.0 is 1500.0
      assert result.order_index == 1500.0
    end
  end

  describe "needs_rebalance?/1" do
    test "returns false for evenly spaced items", %{set: set} do
      refute TestOrder.needs_rebalance?(set)
    end

    test "returns true when values are too close", %{set: set, items: items} do
      [first, second | _] = items

      # Move repeatedly to create tiny gaps
      for _ <- 1..20 do
        TestOrder.move(second, between: {first.id, second.id})
      end

      assert TestOrder.needs_rebalance?(set, threshold: 1.0)
    end

    test "respects custom threshold", %{set: set} do
      # With a very large threshold, even normal spacing triggers
      assert TestOrder.needs_rebalance?(set, threshold: 2000.0)
    end

    test "returns false for empty set" do
      {:ok, empty_set} = Repo.insert(%Schemas.Set{})
      refute TestOrder.needs_rebalance?(empty_set)
    end

    test "returns false for single item" do
      {:ok, set} = Repo.insert(%Schemas.Set{})
      Repo.insert!(%Schemas.Item{set: set, order_index: 1000.0})
      refute TestOrder.needs_rebalance?(set)
    end
  end

  describe "rebalance/2" do
    test "resets to even increments", %{set: set} do
      {:ok, count} = TestOrder.rebalance(set)
      assert count == 5

      items = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.order_index)
      orders = Enum.map(items, & &1.order_index)

      assert orders == [1000.0, 2000.0, 3000.0, 4000.0, 5000.0]
    end

    test "preserves relative order", %{set: set, items: items} do
      [first, second, third | _] = items

      # Create fractional values
      TestOrder.move(third, between: {first.id, second.id})

      original_order =
        TestOrder.siblings(set)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.id)

      {:ok, _} = TestOrder.rebalance(set)

      new_order =
        TestOrder.siblings(set)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.id)

      assert original_order == new_order
    end

    test "can order by different field", %{set: set} do
      {:ok, _} = TestOrder.rebalance(set, order_by: :id)

      items = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.order_index)
      ids = Enum.map(items, & &1.id)

      assert ids == Enum.sort(ids)
    end

    test "can order descending", %{set: set} do
      {:ok, _} = TestOrder.rebalance(set, order_by: {:desc, :id})

      items = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.order_index)
      ids = Enum.map(items, & &1.id)

      assert ids == Enum.sort(ids, :desc)
    end

    test "returns {:ok, 0} for empty set" do
      {:ok, empty_set} = Repo.insert(%Schemas.Set{})
      assert {:ok, 0} = TestOrder.rebalance(empty_set)
    end
  end

  describe "isolation between sets" do
    test "operations don't affect other sets", %{items: items} do
      # Create another set
      {:ok, other_set} = Repo.insert(%Schemas.Set{})
      other_item = Repo.insert!(%Schemas.Item{set: other_set, order_index: 500.0})

      # Move item in first set
      [_first, second | _] = items
      TestOrder.move(second, direction: :up)

      # Other set's item should be unchanged
      reloaded = Repo.get!(Schemas.Item, other_item.id)
      assert reloaded.order_index == 500.0
    end

    test "rebalance only affects target set", %{set: set} do
      # Create another set with specific order
      {:ok, other_set} = Repo.insert(%Schemas.Set{})
      Repo.insert!(%Schemas.Item{set: other_set, order_index: 123.0})
      Repo.insert!(%Schemas.Item{set: other_set, order_index: 456.0})

      # Rebalance first set
      TestOrder.rebalance(set)

      # Other set should be unchanged
      other_items = TestOrder.siblings(other_set) |> Repo.all() |> Enum.sort_by(& &1.order_index)
      orders = Enum.map(other_items, & &1.order_index)

      assert orders == [123.0, 456.0]
    end
  end
end
