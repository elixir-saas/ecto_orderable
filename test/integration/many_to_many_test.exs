defmodule Integration.ManyToManyTest do
  @moduledoc """
  Integration tests for many-to-many ordering with composite primary keys.

  Tests the use case where a join table has its own ordering, allowing
  the same records to exist in multiple ordered sets simultaneously.

  Example: TaskUser join table where each user has their own ordering
  of shared tasks.
  """
  use EctoOrderable.RepoCase

  alias EctoOrderable.TestRepo, as: Repo

  setup do
    {:ok, user} = Repo.insert(%Schemas.User{name: "Test User"})

    tasks =
      for i <- 1..5 do
        {:ok, task} = Repo.insert(%Schemas.Task{title: "Task #{i}"})
        task
      end

    # Create TaskUser join records with order
    task_users =
      tasks
      |> Enum.with_index(1)
      |> Enum.map(fn {task, index} ->
        Repo.insert!(%Schemas.TaskUser{
          task_id: task.id,
          user_id: user.id,
          position: index * 1000.0
        })
      end)

    %{user: user, tasks: tasks, task_users: task_users}
  end

  describe "scope resolution" do
    test "accepts parent struct (user)", %{user: user} do
      assert TestTaskUserOrder.first_order(user) == 1000.0
    end

    test "accepts keyword list", %{user: user} do
      assert TestTaskUserOrder.first_order(user_id: user.id) == 1000.0
    end

    test "accepts join record struct", %{task_users: [task_user | _]} do
      assert TestTaskUserOrder.first_order(task_user) == 1000.0
    end
  end

  describe "basic operations" do
    test "first_order works", %{user: user} do
      assert TestTaskUserOrder.first_order(user) == 1000.0
    end

    test "last_order works", %{user: user} do
      assert TestTaskUserOrder.last_order(user) == 5000.0
    end

    test "next_order works", %{user: user} do
      assert TestTaskUserOrder.next_order(user) == 6000.0
    end

    test "count works", %{user: user} do
      assert TestTaskUserOrder.count(user) == 5
    end

    test "move with direction works", %{task_users: task_users} do
      [first, second | _] = task_users
      result = TestTaskUserOrder.move(second, direction: :up)
      assert result.position < first.position
    end

    test "move with between using composite key map", %{task_users: task_users} do
      [first, second, third | _] = task_users

      # Move third between first and second using composite key maps
      result =
        TestTaskUserOrder.move(third,
          between: {
            %{task_id: first.task_id, user_id: first.user_id},
            %{task_id: second.task_id, user_id: second.user_id}
          }
        )

      assert result.position > first.position
      assert result.position < second.position
    end

    test "move with between using simple task_id (inherits scope)", %{
      task_users: task_users,
      tasks: tasks
    } do
      [first, second, third | _] = task_users
      [task1, task2, _task3 | _] = tasks

      # Move third between first and second using just task_ids
      # The user_id is inherited from the item being moved
      result = TestTaskUserOrder.move(third, between: {task1.id, task2.id})

      assert result.position > first.position
      assert result.position < second.position
    end

    test "move to beginning with simple id", %{task_users: task_users, tasks: tasks} do
      [first, _second, third | _] = task_users
      [task1 | _] = tasks

      result = TestTaskUserOrder.move(third, between: {nil, task1.id})
      assert result.position < first.position
    end

    test "move to end with simple id", %{task_users: task_users, tasks: tasks} do
      [first | _] = task_users
      last_task = List.last(tasks)

      result = TestTaskUserOrder.move(first, between: {last_task.id, nil})
      last_task_user = List.last(task_users)
      assert result.position > last_task_user.position
    end

    test "move to beginning with between", %{task_users: task_users} do
      [first, _second, third | _] = task_users

      result =
        TestTaskUserOrder.move(third,
          between: {nil, %{task_id: first.task_id, user_id: first.user_id}}
        )

      assert result.position < first.position
    end

    test "move to end with between", %{task_users: task_users} do
      [first | _] = task_users
      last = List.last(task_users)

      result =
        TestTaskUserOrder.move(first,
          between: {%{task_id: last.task_id, user_id: last.user_id}, nil}
        )

      assert result.position > last.position
    end

    test "sibling_before works", %{task_users: task_users} do
      [first, second | _] = task_users
      sibling = TestTaskUserOrder.sibling_before(second)
      assert sibling.task_id == first.task_id
      assert sibling.user_id == first.user_id
    end

    test "sibling_after works", %{task_users: task_users} do
      [first, second | _] = task_users
      sibling = TestTaskUserOrder.sibling_after(first)
      assert sibling.task_id == second.task_id
      assert sibling.user_id == second.user_id
    end

    test "siblings returns all task_users for user", %{user: user, task_users: task_users} do
      result = TestTaskUserOrder.siblings(user) |> Repo.all()
      assert length(result) == length(task_users)
    end

    test "rebalance works with composite primary key", %{user: user, task_users: task_users} do
      # Move items around to create fractional values
      [first, second, third | _] = task_users

      TestTaskUserOrder.move(third,
        between: {
          %{task_id: first.task_id, user_id: first.user_id},
          %{task_id: second.task_id, user_id: second.user_id}
        }
      )

      # Rebalance to clean values
      {:ok, count} = TestTaskUserOrder.rebalance(user)
      assert count == 5

      # Verify all values are evenly spaced
      items = TestTaskUserOrder.siblings(user) |> Repo.all() |> Enum.sort_by(& &1.position)
      orders = Enum.map(items, & &1.position)
      assert orders == [1000.0, 2000.0, 3000.0, 4000.0, 5000.0]
    end
  end

  describe "user isolation" do
    test "different users can have different orderings of the same tasks", %{tasks: tasks} do
      # Create two users
      {:ok, user_a} = Repo.insert(%Schemas.User{name: "User A"})
      {:ok, user_b} = Repo.insert(%Schemas.User{name: "User B"})

      [task1, task2, task3 | _] = tasks

      # User A orders: task1, task2, task3
      Repo.insert!(%Schemas.TaskUser{task_id: task1.id, user_id: user_a.id, position: 1000.0})
      Repo.insert!(%Schemas.TaskUser{task_id: task2.id, user_id: user_a.id, position: 2000.0})
      Repo.insert!(%Schemas.TaskUser{task_id: task3.id, user_id: user_a.id, position: 3000.0})

      # User B orders: task3, task1, task2 (different order)
      Repo.insert!(%Schemas.TaskUser{task_id: task3.id, user_id: user_b.id, position: 1000.0})
      Repo.insert!(%Schemas.TaskUser{task_id: task1.id, user_id: user_b.id, position: 2000.0})
      Repo.insert!(%Schemas.TaskUser{task_id: task2.id, user_id: user_b.id, position: 3000.0})

      # Verify User A's order
      user_a_tasks =
        TestTaskUserOrder.siblings(user_a)
        |> Repo.all()
        |> Enum.sort_by(& &1.position)
        |> Enum.map(& &1.task_id)

      assert user_a_tasks == [task1.id, task2.id, task3.id]

      # Verify User B's order
      user_b_tasks =
        TestTaskUserOrder.siblings(user_b)
        |> Repo.all()
        |> Enum.sort_by(& &1.position)
        |> Enum.map(& &1.task_id)

      assert user_b_tasks == [task3.id, task1.id, task2.id]
    end

    test "moving task for one user doesn't affect another user", %{user: user, tasks: tasks} do
      {:ok, other_user} = Repo.insert(%Schemas.User{name: "Other User"})

      # Give other user the same tasks
      other_task_users =
        tasks
        |> Enum.with_index(1)
        |> Enum.map(fn {task, index} ->
          Repo.insert!(%Schemas.TaskUser{
            task_id: task.id,
            user_id: other_user.id,
            position: index * 1000.0
          })
        end)

      # Move task for original user
      task_user = Repo.get_by!(Schemas.TaskUser, task_id: List.first(tasks).id, user_id: user.id)
      TestTaskUserOrder.move(task_user, direction: :down)

      # Other user's ordering should be unchanged
      reloaded =
        TestTaskUserOrder.siblings(other_user)
        |> Repo.all()
        |> Enum.sort_by(& &1.position)

      original_orders = Enum.map(other_task_users, & &1.position)
      reloaded_orders = Enum.map(reloaded, & &1.position)

      assert original_orders == reloaded_orders
    end

    test "rebalancing one user doesn't affect another user", %{user: user, tasks: tasks} do
      {:ok, other_user} = Repo.insert(%Schemas.User{name: "Other User"})

      # Give other user tasks with specific ordering
      [task1, task2 | _] = tasks

      Repo.insert!(%Schemas.TaskUser{
        task_id: task1.id,
        user_id: other_user.id,
        position: 123.0
      })

      Repo.insert!(%Schemas.TaskUser{
        task_id: task2.id,
        user_id: other_user.id,
        position: 456.0
      })

      # Rebalance original user
      TestTaskUserOrder.rebalance(user)

      # Other user's ordering should be unchanged
      other_orders =
        TestTaskUserOrder.siblings(other_user)
        |> Repo.all()
        |> Enum.sort_by(& &1.position)
        |> Enum.map(& &1.position)

      assert other_orders == [123.0, 456.0]
    end
  end

  describe "scope inheritance with between" do
    test "simple id inherits user_id from item being moved", %{
      task_users: task_users,
      tasks: tasks
    } do
      [first, second, _third, _fourth, fifth] = task_users
      [task1, task2 | _] = tasks

      # Move fifth between first and second using just task_ids
      result = TestTaskUserOrder.move(fifth, between: {task1.id, task2.id})

      assert result.position > first.position
      assert result.position < second.position
      # Verify it's still the same user
      assert result.user_id == fifth.user_id
    end

    test "explicit map still works when scope differs", %{user: user, tasks: tasks} do
      # This tests that explicit maps are still supported
      [task1, task2, _task3 | _] = tasks

      [first, second, third | _] =
        TestTaskUserOrder.siblings(user)
        |> Repo.all()
        |> Enum.sort_by(& &1.position)

      result =
        TestTaskUserOrder.move(third,
          between: {
            %{task_id: task1.id, user_id: user.id},
            %{task_id: task2.id, user_id: user.id}
          }
        )

      assert result.position > first.position
      assert result.position < second.position
    end
  end

  describe "adding tasks to user" do
    test "next_order provides correct value for new assignment", %{user: user} do
      {:ok, new_task} = Repo.insert(%Schemas.Task{title: "New Task"})

      order = TestTaskUserOrder.next_order(user)

      task_user =
        Repo.insert!(%Schemas.TaskUser{
          task_id: new_task.id,
          user_id: user.id,
          position: order
        })

      # Should now be last
      assert TestTaskUserOrder.sibling_after(task_user) == nil
      assert TestTaskUserOrder.last_order(user) == order
    end
  end
end
