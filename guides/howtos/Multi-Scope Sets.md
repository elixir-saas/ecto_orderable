# Multi-Scope Sets

A "multi-scope set" partitions items by more than one field. Each unique combination of scope values defines a separate ordered set.

## When to Use Multi-Scope

Use multiple scope fields when ordering depends on the intersection of two or more dimensions:

| Scenario | Scope Fields | Why |
|----------|--------------|-----|
| Project tasks per user | `[:project_id, :user_id]` | Each user has their own task order within each project |
| Kanban cards per board per column | `[:board_id, :column_id]` | Cards are ordered within columns, columns belong to boards |
| Playlist songs per user per playlist | `[:user_id, :playlist_id]` | Users can have multiple playlists, each with its own song order |
| Comments per post per thread | `[:post_id, :parent_id]` | Nested comments ordered within their parent thread |

The key question: **"Does the same item need different orderings based on multiple independent dimensions?"**

If yes, you likely need multi-scope.

## Schema

```elixir
defmodule ProjectItem do
  use Ecto.Schema

  schema "project_items" do
    field :title, :string
    field :position, :float
    belongs_to :project, Project
    belongs_to :user, User
  end
end
```

Each item belongs to both a project and a user. The ordering is specific to that combination—User A's order in Project X is independent of User A's order in Project Y, and independent of User B's order in Project X.

## Order Module

```elixir
defmodule ProjectItemOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: ProjectItem,
    scope: [:project_id, :user_id]
end
```

The order of fields in `scope:` doesn't affect behavior, but conventionally list the "larger" container first (project before user).

## Usage

With multiple scope fields, you must provide all scope values. There are two ways:

### Keyword List (explicit)

```elixir
# Get next order for a new item
order = ProjectItemOrder.next_order(project_id: project.id, user_id: user.id)

# Count items in scope
ProjectItemOrder.count(project_id: project.id, user_id: user.id)

# Get siblings query
ProjectItemOrder.siblings(project_id: project.id, user_id: user.id)
|> Repo.all()

# Rebalance a specific scope
ProjectItemOrder.rebalance(project_id: project.id, user_id: user.id)
```

### Item Struct (implicit)

When you have an item, scope values are extracted automatically:

```elixir
# Move an existing item
ProjectItemOrder.move(item, direction: :up)
ProjectItemOrder.move(item, between: {above_id, below_id})

# Get siblings of an item
ProjectItemOrder.siblings(item) |> Repo.all()

# Check position
ProjectItemOrder.sibling_before(item)
ProjectItemOrder.sibling_after(item)
```

### What Doesn't Work

Unlike single-scope sets, you cannot pass a parent struct directly:

```elixir
# This works for single-scope (user_id only)
TodoOrder.next_order(user)

# This does NOT work for multi-scope
ProjectItemOrder.next_order(user)    # Error: missing project_id
ProjectItemOrder.next_order(project) # Error: missing user_id
```

The library can't know which scope field should receive the struct's id.

## Isolation Guarantees

Each unique combination of scope values is completely isolated:

```elixir
# These are four separate ordered sets:
# 1. Project A, User 1
# 2. Project A, User 2
# 3. Project B, User 1
# 4. Project B, User 2

# Moving an item in set 1 never affects sets 2, 3, or 4
ProjectItemOrder.move(item_in_set_1, direction: :up)

# Rebalancing set 3 never affects sets 1, 2, or 4
ProjectItemOrder.rebalance(project_id: project_b.id, user_id: user_1.id)
```

## Real-World Example: Kanban Board

A Kanban board where users can drag cards between columns, with each column maintaining its own order:

```elixir
defmodule Card do
  use Ecto.Schema

  schema "cards" do
    field :title, :string
    field :position, :float
    belongs_to :board, Board
    belongs_to :column, Column
  end
end

defmodule CardOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: Card,
    scope: [:board_id, :column_id]
end
```

Moving a card within a column:

```elixir
def handle_event("reorder_card", %{"id" => id, "before" => before_id, "after" => after_id}, socket) do
  card = Repo.get!(Card, id)
  before_id = if before_id, do: String.to_integer(before_id)
  after_id = if after_id, do: String.to_integer(after_id)

  CardOrder.move(card, between: {before_id, after_id})

  {:noreply, reload_cards(socket)}
end
```

Moving a card to a different column requires updating the `column_id` and getting a new order:

```elixir
def handle_event("move_to_column", %{"card_id" => card_id, "column_id" => new_column_id}, socket) do
  card = Repo.get!(Card, card_id)
  new_column_id = String.to_integer(new_column_id)

  # Get order for end of new column
  new_order = CardOrder.next_order(board_id: card.board_id, column_id: new_column_id)

  card
  |> Ecto.Changeset.change(column_id: new_column_id, position: new_order)
  |> Repo.update!()

  {:noreply, reload_cards(socket)}
end
```

## Scope from Joined Tables

When a scope field lives on a related table rather than the schema being ordered, use `scope_join` to avoid denormalization:

```elixir
defmodule UserTaskPositionOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: UserTaskPosition,
    scope: [:user_id, :status_id],
    scope_join: [status_id: {Task, :task_id}]
end
```

See the [Scope from Joined Tables](Scope from Joined Tables.md) guide for detailed examples and usage patterns.

## Comparison with Other Patterns

| Pattern | Scope | Use When |
|---------|-------|----------|
| Belongs-To | `[:parent_id]` | Simple parent-child (todos per user) |
| Multi-Scope | `[:parent_a_id, :parent_b_id]` | Items ordered within intersection of parents |
| Multi-Scope + Join | `scope_join: [field: {Schema, :fk}]` | Scope field lives on related table |
| Many-to-Many | `[:user_id]` on join table | Same items, different orderings per user |
| Global | `[]` | Single shared ordering for all users |

Multi-scope is essentially a belongs-to set with multiple parents, where the ordering is specific to the combination of all parents.
