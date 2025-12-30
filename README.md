# EctoOrderable

Flexible ordering for Ecto schemas. Supports belongs-to, many-to-many, and global sets with fractional indexing for efficient reordering.

Designed to integrate seamlessly with [`@phx-hook/sortable`](https://github.com/elixir-saas/phx-hook/tree/main/packages/sortable) for drag-and-drop ordering in Phoenix LiveView.

## Installation

Add `ecto_orderable` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_orderable, "~> 0.3.1"}
  ]
end
```

## Quick Start

### 1. Add an order field to your schema

```elixir
# In a migration
alter table(:todos) do
  add :position, :float
end
```

### 2. Define an Order module

```elixir
defmodule MyApp.TodoOrder do
  use EctoOrderable,
    repo: MyApp.Repo,
    schema: MyApp.Todo,
    scope: [:user_id]
end
```

### 3. Use it

```elixir
alias MyApp.{Repo, Todo, TodoOrder}

# Get next order value for a new todo
order = TodoOrder.next_order(user)
Repo.insert!(%Todo{title: "Buy milk", user_id: user.id, position: order})

# Reorder with direction
TodoOrder.move(todo, direction: :up)
TodoOrder.move(todo, direction: :down)

# Reorder with explicit position (for drag-and-drop)
TodoOrder.move(todo, between: {id_above, id_below})
```

## How It Works

EctoOrderable uses **fractional indexing** - each item has a float `position` that determines its position. When you move an item between two others, it calculates the midpoint:

```
Item A: 1000.0
Item B: 2000.0  ← moving Item C here
Item C: 3000.0

After move:
Item A: 1000.0
Item C: 1500.0  ← (1000 + 2000) / 2
Item B: 2000.0
```

This allows unlimited reordering without updating other rows. After many operations, use `rebalance/2` to reset values to clean increments.

## Use Cases

### Belongs-To Sets

The simplest case - items belong to a parent via foreign key:

```elixir
defmodule TodoOrder do
  use EctoOrderable,
    repo: Repo,
    schema: Todo,
    scope: [:user_id]
end

# Each user has their own ordered list of todos
TodoOrder.move(todo, direction: :up)
```

### Many-To-Many Sets (Team Task Boards)

Each user can have their own ordering of shared tasks:

```elixir
# Schema: TaskUser join table with position
defmodule TaskUser do
  use Ecto.Schema

  @primary_key false
  schema "task_users" do
    field :position, :float
    belongs_to :task, Task, primary_key: true
    belongs_to :user, User, primary_key: true
  end
end

defmodule TaskUserOrder do
  use EctoOrderable,
    repo: Repo,
    schema: TaskUser,
    scope: [:user_id]
end

# User 1 sees tasks in their order, User 2 sees different order
task_user = Repo.get_by!(TaskUser, task_id: task.id, user_id: user.id)
TaskUserOrder.move(task_user, direction: :up)

# For between, just pass the task_ids - scope (user_id) is inherited from the item
TaskUserOrder.move(task_user, between: {above_task.id, below_task.id})
```

### Global Sets

Admin-managed lists with no per-user variation:

```elixir
defmodule TemplateOrder do
  use EctoOrderable,
    repo: Repo,
    schema: OnboardingTemplate,
    scope: []  # Empty scope = global
end

# No scope argument needed
TemplateOrder.next_order()
TemplateOrder.move(template, direction: :up)
```

## API Reference

### Order Module Functions

| Function | Description |
|----------|-------------|
| `next_order(scope)` | Get order value for appending a new item |
| `first_order(scope)` | Get order value of first item |
| `last_order(scope)` | Get order value of last item |
| `count(scope)` | Count items in the set |
| `members(scope)` | Get Ecto query for all items in set |
| `move(item, opts)` | Move an item (`direction:` or `between:`) |
| `sibling_before(item)` | Get item immediately before |
| `sibling_after(item)` | Get item immediately after |
| `needs_rebalance?(scope, opts)` | Check if values are too close |
| `rebalance(scope, opts)` | Reset all values to even increments |

### Scope Arguments

**Set-level operations** (`members`, `count`, `first_order`, `last_order`, `next_order`, `needs_rebalance?`, `rebalance`) accept flexible scope arguments:

```elixir
# Parent struct - extracts ID as first scope field value
TodoOrder.next_order(user)

# Keyword list - explicit scope values (validated)
TodoOrder.next_order(user_id: 123)

# Item struct - extracts scope fields from item
TodoOrder.members(todo)

# No argument - for global sets with scope: []
TemplateOrder.next_order()
```

**Item-level operations** (`move`, `sibling_before`, `sibling_after`) require the actual item struct being operated on:

```elixir
TodoOrder.move(todo, direction: :up)
TodoOrder.sibling_before(todo)
TodoOrder.sibling_after(todo)
```

### Move Options

```elixir
# Move one position up/down
TodoOrder.move(todo, direction: :up)
TodoOrder.move(todo, direction: :down)

# Move to specific position (for drag-and-drop)
TodoOrder.move(todo, between: {id_above, id_below})
TodoOrder.move(todo, between: {nil, first_id})      # Move to beginning
TodoOrder.move(todo, between: {last_id, nil})       # Move to end
```

### Rebalancing

```elixir
# Check if rebalancing is needed
if TodoOrder.needs_rebalance?(user) do
  TodoOrder.rebalance(user)
end

# Initialize ordering for existing records
TodoOrder.rebalance(user, order_by: :inserted_at)
TodoOrder.rebalance(user, order_by: {:desc, :inserted_at})
```

## Phoenix LiveView Integration

EctoOrderable works seamlessly with [`@phx-hook/sortable`](https://github.com/elixir-saas/phx-hook/tree/main/packages/sortable):

```heex
<ul phx-hook="Sortable" data-on-end="reorder_todo">
  <li :for={todo <- @todos} id={"todo-#{todo.id}"} data-item-id={todo.id}>
    <%= todo.title %>
  </li>
</ul>
```

```elixir
def handle_event("reorder_todo", %{"id" => id, "before" => before_id, "after" => after_id}, socket) do
  todo = Repo.get!(Todo, id)
  before_id = if before_id, do: String.to_integer(before_id)
  after_id = if after_id, do: String.to_integer(after_id)

  TodoOrder.move(todo, between: {before_id, after_id})

  {:noreply, reload_todos(socket)}
end
```

See the [Phoenix LiveView Integration guide](guides/howtos/Phoenix%20LiveView%20Integration.md) for complete setup instructions.

## Configuration Options

```elixir
defmodule MyOrder do
  use EctoOrderable,
    repo: MyApp.Repo,           # Required: Ecto repo
    schema: MyApp.Item,          # Required: Ecto schema
    scope: [:parent_id],         # Required: Fields that partition sets ([] for global)
    order_field: :position,   # Optional: Field name (default: :position)
    order_increment: 1000.0      # Optional: Spacing between items (default: 1000.0)
end
```

### Custom Filtering

Override `members_query/2` for additional filtering:

```elixir
defmodule ActiveTodoOrder do
  use EctoOrderable,
    repo: Repo,
    schema: Todo,
    scope: [:user_id]

  def members_query(query, _scope) do
    import Ecto.Query
    where(query, [t], t.status == :active)
  end
end
```

## Documentation

Full documentation available at [HexDocs](https://hexdocs.pm/ecto_orderable).

## License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
