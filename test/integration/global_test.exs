defmodule Integration.GlobalTest do
  @moduledoc """
  Integration tests for global ordering (no scope).

  Tests the use case where all items share a single ordered list
  with no partitioning by parent record.

  Example: Admin-managed onboarding templates shown to all users.
  """
  use EctoOrderable.RepoCase

  alias EctoOrderable.TestRepo, as: Repo

  setup do
    templates =
      for i <- 1..5 do
        Repo.insert!(%Schemas.Template{name: "Template #{i}", order_index: i * 1000.0})
      end

    %{templates: templates}
  end

  describe "scope resolution" do
    test "accepts no argument" do
      assert TestGlobalOrder.first_order() == 1000.0
    end

    test "accepts empty list" do
      assert TestGlobalOrder.first_order([]) == 1000.0
    end

    test "accepts item struct", %{templates: [template | _]} do
      assert TestGlobalOrder.first_order(template) == 1000.0
    end
  end

  describe "first_order/0" do
    test "returns order of first item" do
      assert TestGlobalOrder.first_order() == 1000.0
    end

    test "returns 0.0 when no items exist" do
      Repo.delete_all(Schemas.Template)
      assert TestGlobalOrder.first_order() == 0.0
    end
  end

  describe "last_order/0" do
    test "returns order of last item" do
      assert TestGlobalOrder.last_order() == 5000.0
    end

    test "returns 0.0 when no items exist" do
      Repo.delete_all(Schemas.Template)
      assert TestGlobalOrder.last_order() == 0.0
    end
  end

  describe "next_order/0" do
    test "returns last_order + increment" do
      assert TestGlobalOrder.next_order() == 6000.0
    end

    test "returns increment when no items exist" do
      Repo.delete_all(Schemas.Template)
      assert TestGlobalOrder.next_order() == 1000.0
    end
  end

  describe "count/0" do
    test "returns count of all items" do
      assert TestGlobalOrder.count() == 5
    end

    test "returns 0 when no items exist" do
      Repo.delete_all(Schemas.Template)
      assert TestGlobalOrder.count() == 0
    end
  end

  describe "siblings/1" do
    test "returns query for all items", %{templates: templates} do
      result = TestGlobalOrder.siblings([]) |> Repo.all()
      assert length(result) == length(templates)
    end

    test "works with item struct", %{templates: [template | _]} do
      result = TestGlobalOrder.siblings(template) |> Repo.all()
      assert length(result) == 5
    end
  end

  describe "sibling_before/1" do
    test "returns item before", %{templates: templates} do
      [first, second | _] = templates
      assert TestGlobalOrder.sibling_before(second).id == first.id
    end

    test "returns nil for first item", %{templates: [first | _]} do
      assert TestGlobalOrder.sibling_before(first) == nil
    end
  end

  describe "sibling_after/1" do
    test "returns item after", %{templates: templates} do
      [first, second | _] = templates
      assert TestGlobalOrder.sibling_after(first).id == second.id
    end

    test "returns nil for last item", %{templates: templates} do
      last = List.last(templates)
      assert TestGlobalOrder.sibling_after(last) == nil
    end
  end

  describe "move/2 with direction: :up" do
    test "moves item up one position", %{templates: templates} do
      [first, second | _] = templates
      result = TestGlobalOrder.move(second, direction: :up)

      assert result.order_index < first.order_index
    end

    test "returns unchanged when already first", %{templates: [first | _]} do
      result = TestGlobalOrder.move(first, direction: :up)
      assert result.order_index == first.order_index
    end

    test "places between previous two items", %{templates: templates} do
      [first, second, third | _] = templates

      result = TestGlobalOrder.move(third, direction: :up)

      assert result.order_index > first.order_index
      assert result.order_index < second.order_index
    end
  end

  describe "move/2 with direction: :down" do
    test "moves item down one position", %{templates: templates} do
      [_first, _second, _third, fourth, fifth] = templates
      result = TestGlobalOrder.move(fourth, direction: :down)

      assert result.order_index > fifth.order_index
    end

    test "returns unchanged when already last", %{templates: templates} do
      last = List.last(templates)
      result = TestGlobalOrder.move(last, direction: :down)
      assert result.order_index == last.order_index
    end

    test "places between next two items", %{templates: templates} do
      [first, second, third | _] = templates

      result = TestGlobalOrder.move(first, direction: :down)

      assert result.order_index > second.order_index
      assert result.order_index < third.order_index
    end
  end

  describe "move/2 with between" do
    test "moves between two items", %{templates: templates} do
      [first, second, _third, _fourth, fifth] = templates

      result = TestGlobalOrder.move(fifth, between: {first.id, second.id})

      assert result.order_index > first.order_index
      assert result.order_index < second.order_index
    end

    test "moves to beginning with {nil, first_id}", %{templates: templates} do
      [first, _second, third | _] = templates

      result = TestGlobalOrder.move(third, between: {nil, first.id})

      assert result.order_index < first.order_index
    end

    test "moves to end with {last_id, nil}", %{templates: templates} do
      [first | _] = templates
      last = List.last(templates)

      result = TestGlobalOrder.move(first, between: {last.id, nil})

      assert result.order_index > last.order_index
    end

    test "returns unchanged with {nil, nil} for only item" do
      Repo.delete_all(Schemas.Template)
      template = Repo.insert!(%Schemas.Template{name: "Only", order_index: 1000.0})

      result = TestGlobalOrder.move(template, between: {nil, nil})

      assert result.order_index == template.order_index
    end

    test "calculates midpoint correctly", %{templates: templates} do
      [first, second | _] = templates
      last = List.last(templates)

      result = TestGlobalOrder.move(last, between: {first.id, second.id})

      # Midpoint of 1000.0 and 2000.0 is 1500.0
      assert result.order_index == 1500.0
    end
  end

  describe "needs_rebalance?/0" do
    test "returns false for evenly spaced items" do
      refute TestGlobalOrder.needs_rebalance?()
    end

    test "returns true when values are too close", %{templates: templates} do
      [first, second | _] = templates

      for _ <- 1..20 do
        TestGlobalOrder.move(second, between: {first.id, second.id})
      end

      assert TestGlobalOrder.needs_rebalance?([], threshold: 1.0)
    end

    test "respects custom threshold" do
      assert TestGlobalOrder.needs_rebalance?([], threshold: 2000.0)
    end

    test "returns false when empty" do
      Repo.delete_all(Schemas.Template)
      refute TestGlobalOrder.needs_rebalance?()
    end

    test "returns false for single item" do
      Repo.delete_all(Schemas.Template)
      Repo.insert!(%Schemas.Template{name: "Only", order_index: 1000.0})
      refute TestGlobalOrder.needs_rebalance?()
    end
  end

  describe "rebalance/0" do
    test "resets to even increments" do
      {:ok, count} = TestGlobalOrder.rebalance()
      assert count == 5

      templates =
        TestGlobalOrder.siblings([])
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      orders = Enum.map(templates, & &1.order_index)
      assert orders == [1000.0, 2000.0, 3000.0, 4000.0, 5000.0]
    end

    test "preserves relative order", %{templates: templates} do
      [first, second, third | _] = templates

      # Create fractional values
      TestGlobalOrder.move(third, between: {first.id, second.id})

      original_order =
        TestGlobalOrder.siblings([])
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.id)

      {:ok, _} = TestGlobalOrder.rebalance()

      new_order =
        TestGlobalOrder.siblings([])
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.id)

      assert original_order == new_order
    end

    test "can order by different field" do
      {:ok, _} = TestGlobalOrder.rebalance([], order_by: :id)

      templates =
        TestGlobalOrder.siblings([])
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      ids = Enum.map(templates, & &1.id)
      assert ids == Enum.sort(ids)
    end

    test "can order by name" do
      {:ok, _} = TestGlobalOrder.rebalance([], order_by: :name)

      templates =
        TestGlobalOrder.siblings([])
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      names = Enum.map(templates, & &1.name)
      assert names == Enum.sort(names)
    end

    test "can order descending" do
      {:ok, _} = TestGlobalOrder.rebalance([], order_by: {:desc, :id})

      templates =
        TestGlobalOrder.siblings([])
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      ids = Enum.map(templates, & &1.id)
      assert ids == Enum.sort(ids, :desc)
    end

    test "returns {:ok, 0} when empty" do
      Repo.delete_all(Schemas.Template)
      assert {:ok, 0} = TestGlobalOrder.rebalance()
    end
  end

  describe "adding new items" do
    test "next_order provides correct value for new item" do
      order = TestGlobalOrder.next_order()
      new_template = Repo.insert!(%Schemas.Template{name: "New", order_index: order})

      # Should now be last
      assert TestGlobalOrder.sibling_after(new_template) == nil
      assert TestGlobalOrder.last_order() == order
    end

    test "can insert at beginning" do
      first_order = TestGlobalOrder.first_order()
      new_order = first_order - 1000.0

      new_template = Repo.insert!(%Schemas.Template{name: "New First", order_index: new_order})

      assert TestGlobalOrder.sibling_before(new_template) == nil
      assert TestGlobalOrder.first_order() == new_order
    end

    test "can insert between existing items", %{templates: templates} do
      [first, second | _] = templates
      new_order = (first.order_index + second.order_index) / 2

      new_template = Repo.insert!(%Schemas.Template{name: "Inserted", order_index: new_order})

      assert TestGlobalOrder.sibling_before(new_template).id == first.id
      assert TestGlobalOrder.sibling_after(new_template).id == second.id
    end
  end
end
