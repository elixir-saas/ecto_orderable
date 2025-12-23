defmodule EctoOrderableTest do
  use EctoOrderable.RepoCase

  alias EctoOrderable.TestRepo, as: Repo

  setup do
    {:ok, set} = Repo.insert(%Schemas.Set{})

    items =
      for i <- 0..10 do
        Repo.insert!(%Schemas.Item{set: set, position: i * 1000.0})
      end

    %{set: set, items: items}
  end

  test "version matches README" do
    version = EctoOrderable.MixProject.project()[:version]

    deps_snippet = """
    def deps do
      [
        {:ecto_orderable, "~> #{version}"}
      ]
    end
    """

    assert File.read!("README.md") =~ deps_snippet
  end

  describe "first_order/1" do
    test "with parent struct", %{set: set} do
      assert 0.0 == TestOrder.first_order(set)
    end

    test "with item struct", %{items: [item | _]} do
      assert 0.0 == TestOrder.first_order(item)
    end

    test "with keyword list", %{set: set} do
      assert 0.0 == TestOrder.first_order(set_id: set.id)
    end
  end

  describe "last_order/1" do
    test "with parent struct", %{set: set} do
      assert 10000.0 == TestOrder.last_order(set)
    end

    test "with item struct", %{items: items} do
      item = List.last(items)
      assert 10000.0 == TestOrder.last_order(item)
    end
  end

  describe "next_order/1" do
    test "with parent struct", %{set: set} do
      assert 11000.0 == TestOrder.next_order(set)
    end

    test "with keyword list", %{set: set} do
      assert 11000.0 == TestOrder.next_order(set_id: set.id)
    end
  end

  describe "siblings/1" do
    test "returns query for all items in set", %{set: set, items: items} do
      result = TestOrder.siblings(set) |> Repo.all()
      assert length(result) == length(items)
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

  describe "move/2 with direction" do
    test "move up", %{items: items} do
      [_first, second | _] = items
      result = TestOrder.move(second, direction: :up)
      assert result.position < 0.0
    end

    test "move up when already first returns unchanged", %{items: [first | _]} do
      result = TestOrder.move(first, direction: :up)
      assert result.position == first.position
    end

    test "move down", %{items: items} do
      second_to_last = Enum.at(items, -2)
      result = TestOrder.move(second_to_last, direction: :down)
      assert result.position > 10000.0
    end

    test "move down when already last returns unchanged", %{items: items} do
      last = List.last(items)
      result = TestOrder.move(last, direction: :down)
      assert result.position == last.position
    end
  end

  describe "move/2 with between" do
    test "move between two items", %{items: items} do
      [first, second, third | _] = items
      # Move third between first and second
      result = TestOrder.move(third, between: {first.id, second.id})
      assert result.position > first.position
      assert result.position < second.position
    end

    test "move to beginning", %{items: items} do
      [first, _second, third | _] = items
      result = TestOrder.move(third, between: {nil, first.id})
      assert result.position < first.position
    end

    test "move to end", %{items: items} do
      last = List.last(items)
      [first | _] = items
      result = TestOrder.move(first, between: {last.id, nil})
      assert result.position > last.position
    end

    test "move when only item in set returns unchanged", %{items: [first | _]} do
      result = TestOrder.move(first, between: {nil, nil})
      assert result.position == first.position
    end
  end

  describe "count/1" do
    test "returns count of items in set", %{set: set} do
      assert TestOrder.count(set) == 11
    end

    test "works with keyword list scope", %{set: set} do
      assert TestOrder.count(set_id: set.id) == 11
    end
  end

  describe "needs_rebalance?/1" do
    test "returns false for evenly spaced items", %{set: set} do
      refute TestOrder.needs_rebalance?(set)
    end

    test "returns true when values are too close", %{set: set, items: items} do
      # Move items repeatedly to create very close values
      [first, second, third, fourth | _] = items
      TestOrder.move(third, between: {first.id, second.id})
      TestOrder.move(fourth, between: {first.id, third.id})
      TestOrder.move(second, between: {first.id, fourth.id})

      # Keep moving to make values closer and closer
      reloaded = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.position)
      [a, b | _] = reloaded

      # Move repeatedly between first two to create tiny gaps
      for _ <- 1..20 do
        TestOrder.move(b, between: {a.id, b.id})
      end

      assert TestOrder.needs_rebalance?(set, threshold: 1.0)
    end

    test "respects custom threshold", %{set: set} do
      # With a very large threshold, even normal spacing triggers rebalance
      assert TestOrder.needs_rebalance?(set, threshold: 2000.0)
    end
  end

  describe "rebalance/2" do
    test "rebalances order values to even increments", %{set: set} do
      {:ok, count} = TestOrder.rebalance(set)
      assert count == 11

      items = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.position)

      # Should be evenly spaced at 1000, 2000, 3000, ...
      Enum.each(Enum.with_index(items, 1), fn {item, index} ->
        assert item.position == index * 1000.0
      end)
    end

    test "rebalances after fractional values accumulate", %{set: set, items: items} do
      # Create fractional values by moving items around
      [first, second, third | _] = items
      TestOrder.move(third, between: {first.id, second.id})
      TestOrder.move(second, between: {first.id, third.id})

      # Now rebalance to clean values
      {:ok, _} = TestOrder.rebalance(set)

      reloaded = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.position)
      orders = Enum.map(reloaded, & &1.position)

      # All values should be whole thousands
      assert Enum.all?(orders, fn o -> o == Float.round(o / 1000) * 1000 end)
    end

    test "can order by a different field", %{set: set} do
      # Rebalance ordering by id
      {:ok, _} = TestOrder.rebalance(set, order_by: :id)

      items = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.position)
      ids = Enum.map(items, & &1.id)

      # IDs should be in ascending order (since we ordered by :id)
      assert ids == Enum.sort(ids)
    end

    test "can order by descending", %{set: set} do
      # Rebalance ordering by id descending
      {:ok, _} = TestOrder.rebalance(set, order_by: {:desc, :id})

      items = TestOrder.siblings(set) |> Repo.all() |> Enum.sort_by(& &1.position)
      ids = Enum.map(items, & &1.id)

      # IDs should be in descending order
      assert ids == Enum.sort(ids, :desc)
    end

    test "works with keyword list scope", %{set: set} do
      {:ok, count} = TestOrder.rebalance(set_id: set.id)
      assert count == 11
    end
  end
end
