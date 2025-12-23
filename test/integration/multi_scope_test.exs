defmodule Integration.MultiScopeTest do
  @moduledoc """
  Integration tests for ordering with multiple scope fields.

  Tests the use case where items are partitioned by more than one field,
  such as items belonging to both a project AND a user.

  Example: Project items where each user has their own ordering within each project.
  """
  use EctoOrderable.RepoCase

  alias EctoOrderable.TestRepo, as: Repo

  setup do
    {:ok, user1} = Repo.insert(%Schemas.User{name: "User 1"})
    {:ok, user2} = Repo.insert(%Schemas.User{name: "User 2"})
    {:ok, project1} = Repo.insert(%Schemas.Project{name: "Project 1"})
    {:ok, project2} = Repo.insert(%Schemas.Project{name: "Project 2"})

    # Create items for user1 in project1
    user1_project1_items =
      for i <- 1..3 do
        Repo.insert!(%Schemas.ProjectItem{
          title: "U1P1 Item #{i}",
          project_id: project1.id,
          user_id: user1.id,
          order_index: i * 1000.0
        })
      end

    # Create items for user1 in project2
    user1_project2_items =
      for i <- 1..2 do
        Repo.insert!(%Schemas.ProjectItem{
          title: "U1P2 Item #{i}",
          project_id: project2.id,
          user_id: user1.id,
          order_index: i * 1000.0
        })
      end

    # Create items for user2 in project1
    user2_project1_items =
      for i <- 1..4 do
        Repo.insert!(%Schemas.ProjectItem{
          title: "U2P1 Item #{i}",
          project_id: project1.id,
          user_id: user2.id,
          order_index: i * 1000.0
        })
      end

    %{
      user1: user1,
      user2: user2,
      project1: project1,
      project2: project2,
      user1_project1_items: user1_project1_items,
      user1_project2_items: user1_project2_items,
      user2_project1_items: user2_project1_items
    }
  end

  describe "scope resolution" do
    test "accepts keyword list with all scope fields", %{project1: project1, user1: user1} do
      assert TestMultiScopeOrder.first_order(project_id: project1.id, user_id: user1.id) == 1000.0
    end

    test "accepts item struct", %{user1_project1_items: [item | _]} do
      assert TestMultiScopeOrder.first_order(item) == 1000.0
    end

    test "raises when missing scope field", %{project1: project1} do
      assert_raise KeyError, fn ->
        TestMultiScopeOrder.first_order(project_id: project1.id)
      end
    end

    test "raises when passing single parent struct" do
      # Can't use a single parent struct when there are multiple scope fields
      # because we don't know which scope field the id maps to
      {:ok, user} = Repo.insert(%Schemas.User{name: "Test"})

      # Raises KeyError because the first scope field (:project_id) gets the user.id,
      # but the second scope field (:user_id) can't be resolved
      assert_raise KeyError, fn ->
        TestMultiScopeOrder.first_order(user)
      end
    end
  end

  describe "isolation between scopes" do
    test "same user, different projects have separate orderings", %{
      user1: user1,
      project1: project1,
      project2: project2,
      user1_project1_items: p1_items,
      user1_project2_items: p2_items
    } do
      # Project 1 has 3 items
      assert TestMultiScopeOrder.count(project_id: project1.id, user_id: user1.id) == 3

      # Project 2 has 2 items
      assert TestMultiScopeOrder.count(project_id: project2.id, user_id: user1.id) == 2

      # Siblings are correctly scoped
      p1_siblings = TestMultiScopeOrder.siblings(List.first(p1_items)) |> Repo.all()
      p2_siblings = TestMultiScopeOrder.siblings(List.first(p2_items)) |> Repo.all()

      assert length(p1_siblings) == 3
      assert length(p2_siblings) == 2
    end

    test "same project, different users have separate orderings", %{
      project1: project1,
      user1: user1,
      user2: user2
    } do
      # User 1 has 3 items in project 1
      assert TestMultiScopeOrder.count(project_id: project1.id, user_id: user1.id) == 3

      # User 2 has 4 items in project 1
      assert TestMultiScopeOrder.count(project_id: project1.id, user_id: user2.id) == 4
    end

    test "moving item in one scope doesn't affect other scopes", %{
      user1_project1_items: p1_items,
      user1_project2_items: p2_items,
      user2_project1_items: u2_items
    } do
      # Record original orders
      p2_original = Enum.map(p2_items, & &1.order_index)
      u2_original = Enum.map(u2_items, & &1.order_index)

      # Move item in user1/project1
      [_first, second | _] = p1_items
      TestMultiScopeOrder.move(second, direction: :up)

      # User1/Project2 should be unchanged
      p2_reloaded =
        TestMultiScopeOrder.siblings(List.first(p2_items))
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.order_index)

      assert p2_reloaded == p2_original

      # User2/Project1 should be unchanged
      u2_reloaded =
        TestMultiScopeOrder.siblings(List.first(u2_items))
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.order_index)

      assert u2_reloaded == u2_original
    end

    test "rebalancing one scope doesn't affect others", %{
      project1: project1,
      user1: user1,
      user1_project2_items: p2_items,
      user2_project1_items: u2_items
    } do
      # Record original orders
      p2_original = Enum.map(p2_items, & &1.order_index)
      u2_original = Enum.map(u2_items, & &1.order_index)

      # Rebalance user1/project1
      {:ok, count} = TestMultiScopeOrder.rebalance(project_id: project1.id, user_id: user1.id)
      assert count == 3

      # User1/Project2 should be unchanged
      p2_reloaded =
        TestMultiScopeOrder.siblings(List.first(p2_items))
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.order_index)

      assert p2_reloaded == p2_original

      # User2/Project1 should be unchanged
      u2_reloaded =
        TestMultiScopeOrder.siblings(List.first(u2_items))
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.order_index)

      assert u2_reloaded == u2_original
    end
  end

  describe "basic operations with multi-scope" do
    test "first_order returns correct value", %{project1: project1, user1: user1} do
      assert TestMultiScopeOrder.first_order(project_id: project1.id, user_id: user1.id) == 1000.0
    end

    test "last_order returns correct value", %{project1: project1, user1: user1} do
      assert TestMultiScopeOrder.last_order(project_id: project1.id, user_id: user1.id) == 3000.0
    end

    test "next_order returns correct value", %{project1: project1, user1: user1} do
      assert TestMultiScopeOrder.next_order(project_id: project1.id, user_id: user1.id) == 4000.0
    end

    test "count returns correct value", %{project1: project1, user2: user2} do
      assert TestMultiScopeOrder.count(project_id: project1.id, user_id: user2.id) == 4
    end

    test "sibling_before works", %{user1_project1_items: items} do
      [first, second | _] = items
      sibling = TestMultiScopeOrder.sibling_before(second)
      assert sibling.id == first.id
    end

    test "sibling_after works", %{user1_project1_items: items} do
      [first, second | _] = items
      sibling = TestMultiScopeOrder.sibling_after(first)
      assert sibling.id == second.id
    end
  end

  describe "move operations" do
    test "move with direction", %{user1_project1_items: items} do
      [first, second | _] = items
      result = TestMultiScopeOrder.move(second, direction: :up)

      assert result.order_index < first.order_index
    end

    test "move with between using ids", %{user1_project1_items: items} do
      [first, second, third] = items

      result = TestMultiScopeOrder.move(third, between: {first.id, second.id})

      assert result.order_index > first.order_index
      assert result.order_index < second.order_index
    end

    test "move to beginning", %{user1_project1_items: items} do
      [first, _second, third] = items

      result = TestMultiScopeOrder.move(third, between: {nil, first.id})

      assert result.order_index < first.order_index
    end

    test "move to end", %{user1_project1_items: items} do
      [first, _second, third] = items

      result = TestMultiScopeOrder.move(first, between: {third.id, nil})

      assert result.order_index > third.order_index
    end
  end

  describe "rebalance" do
    test "rebalances correctly", %{project1: project1, user1: user1} do
      {:ok, count} = TestMultiScopeOrder.rebalance(project_id: project1.id, user_id: user1.id)
      assert count == 3

      items =
        TestMultiScopeOrder.siblings(project_id: project1.id, user_id: user1.id)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      orders = Enum.map(items, & &1.order_index)
      assert orders == [1000.0, 2000.0, 3000.0]
    end

    test "rebalance with order_by option", %{project1: project1, user2: user2} do
      {:ok, _} =
        TestMultiScopeOrder.rebalance(
          [project_id: project1.id, user_id: user2.id],
          order_by: {:desc, :id}
        )

      items =
        TestMultiScopeOrder.siblings(project_id: project1.id, user_id: user2.id)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      ids = Enum.map(items, & &1.id)
      assert ids == Enum.sort(ids, :desc)
    end
  end

  describe "adding new items" do
    test "next_order provides correct value for new item", %{project1: project1, user1: user1} do
      order = TestMultiScopeOrder.next_order(project_id: project1.id, user_id: user1.id)

      new_item =
        Repo.insert!(%Schemas.ProjectItem{
          title: "New Item",
          project_id: project1.id,
          user_id: user1.id,
          order_index: order
        })

      # Should be last
      assert TestMultiScopeOrder.sibling_after(new_item) == nil
      assert TestMultiScopeOrder.last_order(project_id: project1.id, user_id: user1.id) == order
    end

    test "empty scope returns correct next_order", %{project2: project2, user2: user2} do
      # This scope has no items yet
      order = TestMultiScopeOrder.next_order(project_id: project2.id, user_id: user2.id)
      assert order == 1000.0
    end
  end
end
