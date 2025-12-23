# Getting Started

Ecto Orderable provides a convenient interface for ordering items in well-defined sets in your database via Ecto.

## Definitions

* A **set** is all records that can be ordered relative to each other, defined by equality on "scope" fields.
* An **item** is a specific record within a set, which can change its position relative to other items.
* A **scope** is the list of fields that partition items into sets (e.g., `[:user_id]` means each user has their own ordered set).

## Quick Example

```elixir
defmodule TodoOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: Todo,
    scope: [:user_id]
end

# Get next order value for a new todo
order = TodoOrder.next_order(user)
Repo.insert!(%Todo{title: "Buy milk", user_id: user.id, order_index: order})

# Reorder an existing todo
TodoOrder.move(todo, direction: :up)
TodoOrder.move(todo, between: {id_above, id_below})
```

## Initializing Order for Existing Records

When adding ordering to an existing feature, your records won't have `order_index` values yet. Use `rebalance/2` to initialize them based on another field:

```elixir
# Initialize order based on creation time
TodoOrder.rebalance(user, order_by: :inserted_at)
```

This assigns evenly spaced order values (1000, 2000, 3000, ...) to all items in the set, sorted by the specified field.

You can also use `rebalance/2` to reset order values after many drag-and-drop operations have created fractional values:

```elixir
# Rebalance based on current order
TodoOrder.rebalance(user)

# Check if rebalancing is needed (values too close together)
if TodoOrder.needs_rebalance?(user) do
  TodoOrder.rebalance(user)
end
```

## Authorization

This library handles ordering mechanics only. Authorization is your application's responsibility.

**Key assumptions:**

1. **Authorization happens before calling the library.** The library does not check whether the current user is allowed to reorder items. Validate permissions in your application layer before calling `move/2` or other functions.

2. **Ordering is a set-level operation.** Even though you update one item's `order_index`, the meaning of "position 3" is relative to all siblings. If a user can reorder within a set, they implicitly have access to that set's ordering.

3. **The `between:` option trusts the caller.** When you call `move(item, between: {id_above, id_below})`, the library does not verify those IDs belong to the same set. Passing IDs from a different set will produce nonsensical results.

**The scope defines the authorization boundary.** If your scope is `[:user_id]`, you're implicitly modeling "users can reorder their own items." If it's `[:team_id]`, then "team members share ordering." Design your scopes to match your access control model.
