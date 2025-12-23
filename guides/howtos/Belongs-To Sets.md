# Belongs-To Sets

A "belongs-to set" is the simplest of sets, where the set is all records belonging to another record.

For example, `Todo` that belongs to `User`, via a `:user_id` foreign key.

## Schema

```elixir
defmodule Todo do
  use Ecto.Schema

  schema "todos" do
    field :title, :string
    field :position, :float
    belongs_to :user, User
  end
end
```

Key characteristics:
- The `position` field lives directly on the item being ordered
- Each user has their own independent ordering of todos
- Moving a todo only affects that one record's `position`

## Order Module

```elixir
defmodule TodoOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: Todo,
    scope: [:user_id]
end
```

The `scope: [:user_id]` tells the library that items are partitioned by `user_id` - each user has their own ordered set.

## Usage

```elixir
# Get next order value for a new todo
order = TodoOrder.next_order(user)
Repo.insert!(%Todo{title: "Buy milk", user_id: user.id, position: order})

# Reorder an existing todo
TodoOrder.move(todo, direction: :up)
TodoOrder.move(todo, between: {id_above, id_below})

# Query helpers
TodoOrder.first_order(user)
TodoOrder.last_order(todo)
TodoOrder.members(user) |> Repo.all()
```

## Common Variations

**Multiple scope fields**: A todo might belong to both a `user_id` and a `project_id`. See the [Multi-Scope Sets](Multi-Scope Sets.md) guide for this pattern.

**Self-referential**: Comments belonging to a parent comment (nested threads). Use `scope: [:parent_id]` where `parent_id` references the same table. Root comments with `parent_id: nil` form their own set.

**With additional filters**: "Active todos for user X" - override `members_query/2` to add extra conditions:

```elixir
defmodule ActiveTodoOrder do
  use EctoOrderable, repo: MyRepo, schema: Todo, scope: [:user_id]

  def members_query(query, _scope) do
    import Ecto.Query
    where(query, [t], t.status == :active)
  end
end
```
