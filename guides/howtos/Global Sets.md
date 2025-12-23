# Global Sets

A "global" set is a set that is scoped to records without querying by a particular ID.

For example, `OnboardingTaskTemplate` might be an admin-managed set that defines the order of tasks a user must complete during onboarding to an app. Since the order is managed by admins, it can exist as a global order, not scoped to a particular user or organization.

## Schema

```elixir
defmodule OnboardingTaskTemplate do
  use Ecto.Schema

  schema "onboarding_task_templates" do
    field :title, :string
    field :position, :float
    field :active, :boolean, default: true
  end
end
```

Key characteristics:
- The `position` field lives directly on the item
- There is only ONE ordering for all records (no per-user or per-parent variation)
- The "set" is effectively the entire table (or a filtered subset)

## Order Module

```elixir
defmodule TemplateOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: OnboardingTaskTemplate,
    scope: []
end
```

The `scope: []` (empty list) indicates there are no partitioning fields - all records belong to one global set.

## Usage

```elixir
# Get next order value for a new template
order = TemplateOrder.next_order()
Repo.insert!(%OnboardingTaskTemplate{title: "Welcome", position: order})

# Reorder an existing template
TemplateOrder.move(template, direction: :up)
TemplateOrder.move(template, between: {id_above, id_below})

# Query helpers - no scope argument needed
TemplateOrder.first_order()
TemplateOrder.last_order()
TemplateOrder.siblings(template) |> Repo.all()
```

## Filtered Global Sets

If you need to order only a subset of records (e.g., only active templates), override `siblings_query/2`:

```elixir
defmodule ActiveTemplateOrder do
  use EctoOrderable,
    repo: MyRepo,
    schema: OnboardingTaskTemplate,
    scope: []

  def siblings_query(query, _scope) do
    import Ecto.Query
    where(query, [t], t.active == true)
  end
end
```

## Possible Variations

**Multi-tenant global**: Global within a tenant, but each tenant has their own ordering. This is really just belongs-to where the parent is a Tenant/Organization - use `scope: [:tenant_id]`.

**Filtered global**: "All active templates" vs "all archived templates" - use separate Order modules with different `siblings_query/2` overrides, as shown above.

**Multiple global orderings**: Same records ordered differently for different purposes. Use multiple `position` fields (e.g., `priority_order`, `display_order`) with separate Order modules specifying different `order_field:` options.
