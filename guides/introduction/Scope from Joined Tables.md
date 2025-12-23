# Scope from Joined Tables

Sometimes a scope field doesn't live on the schema you're ordering—it lives on a related table. Rather than denormalizing the field, you can use `scope_join` to tell the library to join to the related table.

## The Problem

Consider a Kanban board where:
- `Task` has a `status_id` (To Do, Doing, Done)
- `UserTaskPosition` stores each user's personal ordering of tasks
- You want to order positions by `user_id` and `status_id`

The challenge: `status_id` is on `Task`, not `UserTaskPosition`.

```elixir
defmodule Task do
  use Ecto.Schema

  schema "tasks" do
    field :title, :string
    belongs_to :status, Status
    belongs_to :project, Project
  end
end

defmodule UserTaskPosition do
  use Ecto.Schema

  schema "user_task_positions" do
    field :position, :float
    belongs_to :user, User
    belongs_to :task, Task
  end
end
```

You could denormalize `status_id` onto `UserTaskPosition`, but that creates data synchronization headaches. When a task moves to a different status, you'd need to update every user's position record.

## The Solution: scope_join

Use `scope_join` to join to the related table:

```elixir
defmodule UserTaskPositionOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: UserTaskPosition,
    scope: [:user_id, :status_id],
    scope_join: [status_id: {Task, :task_id}]
end
```

The format is `[field: {JoinedSchema, :foreign_key}]`:
- `status_id` — the scope field name (exists on `Task`)
- `Task` — the schema to join to
- `:task_id` — the foreign key on `UserTaskPosition` that references `Task`

The library will automatically join `UserTaskPosition` to `Task` via `task_id`, then filter by `status_id` on the joined `Task` record.

## Usage

### With Keyword Lists

Provide scope values directly—no preloading needed:

```elixir
# Get next order for a new position
order = UserTaskPositionOrder.next_order(user_id: user.id, status_id: status.id)

# Count positions in a scope
UserTaskPositionOrder.count(user_id: user.id, status_id: status.id)

# Get all siblings
UserTaskPositionOrder.siblings(user_id: user.id, status_id: status.id)
|> Repo.all()

# Rebalance a scope
UserTaskPositionOrder.rebalance(user_id: user.id, status_id: status.id)
```

### With Item Structs

When passing an item struct, the joined association **must be preloaded**:

```elixir
# Preload the task association
position = Repo.preload(position, :task)

# Now these work—status_id is resolved from position.task.status_id
UserTaskPositionOrder.move(position, direction: :up)
UserTaskPositionOrder.sibling_before(position)
UserTaskPositionOrder.sibling_after(position)
```

Without preloading, you'll get an error:

```elixir
# Error: Association :task must be preloaded to resolve :status_id
UserTaskPositionOrder.move(position, direction: :up)
```

## Real-World Example: Personal Kanban

Here's a complete example of a Kanban board where each user has their own ordering of tasks within each status column:

```elixir
# When a user drags a task within a column
def reorder_task(user, position_id, before_id, after_id) do
  position =
    Repo.get!(UserTaskPosition, position_id)
    |> Repo.preload(:task)

  # Verify the position belongs to this user
  if position.user_id != user.id do
    {:error, :unauthorized}
  else
    UserTaskPositionOrder.move(position, between: {before_id, after_id})
    {:ok, position}
  end
end

# When a task moves to a new status, update positions for all users
def move_task_to_status(task, new_status_id) do
  # Update the task's status
  task
  |> Ecto.Changeset.change(status_id: new_status_id)
  |> Repo.update!()

  # Each user's position automatically becomes part of the new status's set
  # because scope_join reads status_id from the task.
  # Optionally rebalance each affected user's positions in the new status.
end

# When creating a position for a user who hasn't seen this task yet
def create_position_for_user(user, task) do
  order = UserTaskPositionOrder.next_order(
    user_id: user.id,
    status_id: task.status_id
  )

  %UserTaskPosition{}
  |> Ecto.Changeset.change(
    user_id: user.id,
    task_id: task.id,
    position: order
  )
  |> Repo.insert!()
end
```

## When to Use scope_join

**Use `scope_join` when:**
- A scope field lives on a related table
- You want to avoid denormalizing the field
- The relationship is stable (the join is always valid)
- Data consistency is more important than query performance

**Consider denormalization instead when:**
- Performance is critical (joins add overhead)
- The related field changes very frequently
- You need to query positions without joining
- You're already denormalizing other fields

## Multiple Joined Scopes

You can join multiple scope fields from different tables:

```elixir
defmodule ComplexOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: MySchema,
    scope: [:user_id, :category_id, :status_id],
    scope_join: [
      category_id: {Item, :item_id},
      status_id: {Item, :item_id}
    ]
end
```

Both `category_id` and `status_id` come from `Item`, accessed via the `item_id` foreign key.
