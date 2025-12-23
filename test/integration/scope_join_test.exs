defmodule Integration.ScopeJoinTest do
  @moduledoc """
  Integration tests for scope_join functionality.

  Tests the use case where a scope field lives on a related table
  rather than the schema being ordered. This avoids denormalization
  by using a join to access the scope value.

  Example: UserTaskPosition ordered per user per status, where
  status_id comes from the associated Task.
  """
  use EctoOrderable.RepoCase

  alias EctoOrderable.TestRepo, as: Repo

  setup do
    {:ok, project} = Repo.insert(%Schemas.Project{name: "Test Project"})
    {:ok, user1} = Repo.insert(%Schemas.User{name: "User 1"})
    {:ok, user2} = Repo.insert(%Schemas.User{name: "User 2"})

    {:ok, todo_status} =
      Repo.insert(%Schemas.Status{name: "To Do", project_id: project.id, order_index: 1000.0})

    {:ok, doing_status} =
      Repo.insert(%Schemas.Status{name: "Doing", project_id: project.id, order_index: 2000.0})

    {:ok, done_status} =
      Repo.insert(%Schemas.Status{name: "Done", project_id: project.id, order_index: 3000.0})

    # Create tasks in different statuses
    {:ok, task1} =
      Repo.insert(%Schemas.Task{
        title: "Task 1",
        status_id: todo_status.id,
        project_id: project.id
      })

    {:ok, task2} =
      Repo.insert(%Schemas.Task{
        title: "Task 2",
        status_id: todo_status.id,
        project_id: project.id
      })

    {:ok, task3} =
      Repo.insert(%Schemas.Task{
        title: "Task 3",
        status_id: doing_status.id,
        project_id: project.id
      })

    {:ok, task4} =
      Repo.insert(%Schemas.Task{
        title: "Task 4",
        status_id: done_status.id,
        project_id: project.id
      })

    # Create positions for user1
    user1_positions = [
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user1.id,
        task_id: task1.id,
        order_index: 1000.0
      }),
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user1.id,
        task_id: task2.id,
        order_index: 2000.0
      }),
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user1.id,
        task_id: task3.id,
        order_index: 1000.0
      }),
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user1.id,
        task_id: task4.id,
        order_index: 1000.0
      })
    ]

    # Create positions for user2 (different order in todo)
    user2_positions = [
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user2.id,
        task_id: task2.id,
        order_index: 1000.0
      }),
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user2.id,
        task_id: task1.id,
        order_index: 2000.0
      }),
      Repo.insert!(%Schemas.UserTaskPosition{
        user_id: user2.id,
        task_id: task3.id,
        order_index: 1000.0
      })
    ]

    %{
      project: project,
      user1: user1,
      user2: user2,
      todo_status: todo_status,
      doing_status: doing_status,
      done_status: done_status,
      tasks: [task1, task2, task3, task4],
      user1_positions: user1_positions,
      user2_positions: user2_positions
    }
  end

  describe "scope resolution with keyword list" do
    test "accepts keyword list with all scope fields", %{user1: user1, todo_status: status} do
      assert TestScopeJoinOrder.first_order(user_id: user1.id, status_id: status.id) == 1000.0
    end

    test "counts correctly per user per status", %{
      user1: user1,
      user2: user2,
      todo_status: todo,
      doing_status: doing
    } do
      # User1 has 2 tasks in To Do
      assert TestScopeJoinOrder.count(user_id: user1.id, status_id: todo.id) == 2

      # User2 also has 2 tasks in To Do
      assert TestScopeJoinOrder.count(user_id: user2.id, status_id: todo.id) == 2

      # User1 has 1 task in Doing
      assert TestScopeJoinOrder.count(user_id: user1.id, status_id: doing.id) == 1

      # User2 also has 1 task in Doing
      assert TestScopeJoinOrder.count(user_id: user2.id, status_id: doing.id) == 1
    end

    test "next_order works with keyword list", %{user1: user1, todo_status: status} do
      assert TestScopeJoinOrder.next_order(user_id: user1.id, status_id: status.id) == 3000.0
    end
  end

  describe "scope resolution with preloaded item" do
    test "resolves status_id from preloaded task association", %{user1_positions: [pos | _]} do
      # Preload the task association
      pos = Repo.preload(pos, :task)

      # Should work with preloaded item
      result = TestScopeJoinOrder.sibling_after(pos)
      assert result != nil
    end

    test "raises when task association is not preloaded", %{user1_positions: [pos | _]} do
      # Without preload, should raise
      assert_raise ArgumentError, ~r/must be preloaded/, fn ->
        TestScopeJoinOrder.sibling_after(pos)
      end
    end
  end

  describe "siblings query uses join" do
    test "returns correct siblings for user and status via join", %{
      user1: user1,
      todo_status: status
    } do
      siblings =
        TestScopeJoinOrder.siblings(user_id: user1.id, status_id: status.id) |> Repo.all()

      assert length(siblings) == 2
    end

    test "different users see different counts in same status", %{
      user1: user1,
      user2: user2,
      done_status: done
    } do
      # User1 has 1 task in Done
      user1_count = TestScopeJoinOrder.count(user_id: user1.id, status_id: done.id)
      assert user1_count == 1

      # User2 has 0 tasks in Done
      user2_count = TestScopeJoinOrder.count(user_id: user2.id, status_id: done.id)
      assert user2_count == 0
    end
  end

  describe "move operations" do
    test "move with direction works", %{user1: user1, todo_status: status} do
      positions =
        TestScopeJoinOrder.siblings(user_id: user1.id, status_id: status.id)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Repo.preload(:task)

      [first, second] = positions

      result = TestScopeJoinOrder.move(second, direction: :up)
      assert result.order_index < first.order_index
    end

    test "move with between using ids", %{user1: user1, todo_status: status} do
      # Get positions in todo status
      positions =
        TestScopeJoinOrder.siblings(user_id: user1.id, status_id: status.id)
        |> Repo.all()
        |> Repo.preload(:task)

      [first, second] = Enum.sort_by(positions, & &1.order_index)

      # Move second between nil and first (to beginning)
      result = TestScopeJoinOrder.move(second, between: {nil, first.id})
      assert result.order_index < first.order_index
    end
  end

  describe "rebalance" do
    test "rebalances correctly using join for scope", %{user1: user1, todo_status: status} do
      {:ok, count} = TestScopeJoinOrder.rebalance(user_id: user1.id, status_id: status.id)
      assert count == 2

      positions =
        TestScopeJoinOrder.siblings(user_id: user1.id, status_id: status.id)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)

      orders = Enum.map(positions, & &1.order_index)
      assert orders == [1000.0, 2000.0]
    end
  end

  describe "isolation" do
    test "operations on one user don't affect another", %{
      user1: user1,
      user2: user2,
      todo_status: status
    } do
      # Record user2's original order
      user2_original =
        TestScopeJoinOrder.siblings(user_id: user2.id, status_id: status.id)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.order_index)

      # Rebalance user1
      TestScopeJoinOrder.rebalance(user_id: user1.id, status_id: status.id)

      # User2 should be unchanged
      user2_after =
        TestScopeJoinOrder.siblings(user_id: user2.id, status_id: status.id)
        |> Repo.all()
        |> Enum.sort_by(& &1.order_index)
        |> Enum.map(& &1.order_index)

      assert user2_original == user2_after
    end

    test "operations on one status don't affect another", %{
      user1: user1,
      todo_status: todo,
      doing_status: doing
    } do
      # Record doing's original order
      doing_original =
        TestScopeJoinOrder.siblings(user_id: user1.id, status_id: doing.id)
        |> Repo.all()
        |> Enum.map(& &1.order_index)

      # Rebalance todo
      TestScopeJoinOrder.rebalance(user_id: user1.id, status_id: todo.id)

      # Doing should be unchanged
      doing_after =
        TestScopeJoinOrder.siblings(user_id: user1.id, status_id: doing.id)
        |> Repo.all()
        |> Enum.map(& &1.order_index)

      assert doing_original == doing_after
    end
  end
end
