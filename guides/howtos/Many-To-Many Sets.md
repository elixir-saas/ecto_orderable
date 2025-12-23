# Many-To-Many Sets

A "many-to-many" set is useful in team environments, as it allows the same records to exist in multiple ordered sets simultaneously.

For example, `TaskUser` might be used to join between `Task` and `User` records. Placing the `:order_index` field on `TaskUser` will define a set of tasks each belonging to specific users. In doing so, we allow tasks to be ordered independently by each user in an organization.

## Schema

```elixir
defmodule Task do
  use Ecto.Schema

  schema "tasks" do
    field :title, :string
    many_to_many :users, User, join_through: TaskUser
  end
end

defmodule TaskUser do
  use Ecto.Schema

  @primary_key false
  schema "task_users" do
    field :order_index, :float
    belongs_to :task, Task, primary_key: true
    belongs_to :user, User, primary_key: true
  end
end
```

Note: Join tables often use composite primary keys (`task_id` + `user_id`) rather than a separate `id` field.

Key characteristics:
- The `order_index` field lives on the **join table**, not on the task itself
- The same task can have different positions for different users
- The "item" being moved is the `TaskUser` join record, not the `Task`

## Order Module

```elixir
defmodule TaskUserOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: TaskUser,
    scope: [:user_id]
end
```

The `scope: [:user_id]` means each user has their own ordered list of tasks.

## Usage

When reordering, you pass the join record, not the task:

```elixir
# Get the join record
task_user = Repo.get_by!(TaskUser, task_id: task.id, user_id: user.id)

# Move it
TaskUserOrder.move(task_user, direction: :up)

# For between, just pass the task_ids - the scope (user_id) is inherited from the item
TaskUserOrder.move(task_user, between: {above_task.id, below_task.id})

# Get next order for assigning a new task to a user
order = TaskUserOrder.next_order(user)
Repo.insert!(%TaskUser{task_id: task.id, user_id: user.id, order_index: order})
```

The `between:` option is smart about composite keys. Since the `user_id` is already known from the `task_user` being moved, you only need to specify the `task_id` of the siblings. The library figures out that `task_id` is the "identity" field (primary key minus scope).

This can feel indirect. The user thinks "I'm reordering my tasks" but the code operates on join records.

## Alternative Perspective: "Tasks per User" vs "Users per Task"

The same join table could support two different orderings:
- **Tasks per user**: Each user has their own ordered list of tasks (`scope: [:user_id]`)
- **Users per task**: Each task has an ordered list of assigned users (`scope: [:task_id]`)

These would be two separate Order modules with different scopes:

```elixir
defmodule TaskUserOrder do
  use EctoOrderable, repo: MyRepo, schema: TaskUser, scope: [:user_id]
end

defmodule UserTaskOrder do
  use EctoOrderable, repo: MyRepo, schema: TaskUser, scope: [:task_id]
end
```
