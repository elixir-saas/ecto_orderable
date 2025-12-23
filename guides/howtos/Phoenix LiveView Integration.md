# Phoenix LiveView Integration

This guide shows how to integrate EctoOrderable with [@phx-hook/sortable](https://github.com/elixir-saas/phx-hook/tree/main/packages/sortable) for drag-and-drop reordering in Phoenix LiveView.

## Overview

The `@phx-hook/sortable` package wraps [Sortable.js](https://sortablejs.github.io/Sortable/) for LiveView. When a user drags an item to a new position, it sends an event with:
- The ID of the moved item
- The ID of the item now before it (or `nil`)
- The ID of the item now after it (or `nil`)

This maps directly to EctoOrderable's `move/2` with the `between:` option.

## Setup

### 1. Install the JavaScript package

```bash
npm install @phx-hook/sortable --save
```

Download Sortable.js from the [releases page](https://github.com/SortableJS/Sortable/releases) and place it in `assets/vendor/Sortable.js`.

### 2. Configure the hook

In your `app.js`:

```javascript
import Sortable from "../vendor/Sortable";
import SortableHook from "@phx-hook/sortable";

const hooks = {
  Sortable: SortableHook(Sortable, {
    animation: 150,
    ghostClass: "sortable-ghost",
  }),
};

let liveSocket = new LiveSocket("/live", Socket, { hooks, params: { _csrf_token: csrfToken } });
```

### 3. Define your Order module

```elixir
defmodule MyApp.TodoOrder do
  use EctoOrderable,
    repo: MyApp.Repo,
    schema: MyApp.Todo,
    scope: [:user_id]
end
```

## LiveView Implementation

### Template

```heex
<ul
  id="todo-list"
  phx-hook="Sortable"
  data-on-end="reorder_todo"
>
  <li :for={todo <- @todos} id={"todo-#{todo.id}"} data-item-id={todo.id}>
    <%= todo.title %>
  </li>
</ul>
```

Key attributes:
- `phx-hook="Sortable"` - Attaches the sortable behavior
- `data-on-end="reorder_todo"` - Event name sent to LiveView when drag ends
- `data-item-id={todo.id}` - Identifies each item (used in the event payload)

### Event Handler

```elixir
defmodule MyAppWeb.TodoLive do
  use MyAppWeb, :live_view

  alias MyApp.{Repo, Todo, TodoOrder}

  def mount(_params, _session, socket) do
    todos = Todo |> where(user_id: ^socket.assigns.current_user.id) |> order_by(:position) |> Repo.all()
    {:ok, assign(socket, :todos, todos)}
  end

  def handle_event("reorder_todo", %{"id" => id, "before" => before_id, "after" => after_id}, socket) do
    todo = Repo.get!(Todo, id)

    # Convert string IDs to integers (or nil)
    before_id = if before_id, do: String.to_integer(before_id)
    after_id = if after_id, do: String.to_integer(after_id)

    TodoOrder.move(todo, between: {before_id, after_id})

    # Reload the list to reflect new order
    todos = Todo |> where(user_id: ^socket.assigns.current_user.id) |> order_by(:position) |> Repo.all()
    {:noreply, assign(socket, :todos, todos)}
  end
end
```

## Optimistic UI Updates

For a smoother experience, you can update the UI optimistically before the server responds. The hook automatically reorders the DOM, so users see immediate feedback.

If you want to avoid refetching the entire list, you can reorder the assigns in memory:

```elixir
def handle_event("reorder_todo", %{"id" => id, "before" => before_id, "after" => after_id}, socket) do
  id = String.to_integer(id)
  todo = Enum.find(socket.assigns.todos, &(&1.id == id))

  before_id = if before_id, do: String.to_integer(before_id)
  after_id = if after_id, do: String.to_integer(after_id)

  # Persist to database
  updated_todo = TodoOrder.move(todo, between: {before_id, after_id})

  # Update assigns in place
  todos =
    socket.assigns.todos
    |> Enum.reject(&(&1.id == id))
    |> insert_at_position(updated_todo, before_id, after_id)

  {:noreply, assign(socket, :todos, todos)}
end

defp insert_at_position(todos, item, before_id, _after_id) when is_integer(before_id) do
  idx = Enum.find_index(todos, &(&1.id == before_id))
  List.insert_at(todos, idx + 1, item)
end

defp insert_at_position(todos, item, nil, after_id) when is_integer(after_id) do
  idx = Enum.find_index(todos, &(&1.id == after_id))
  List.insert_at(todos, idx, item)
end

defp insert_at_position(todos, item, nil, nil) do
  [item | todos]
end
```

## Many-to-Many with Composite Keys

For join tables with composite primary keys, the scope is inherited from the item being moved. Just pass the task IDs directly:

```elixir
def handle_event("reorder_task", %{"id" => task_id, "before" => before_id, "after" => after_id}, socket) do
  user_id = socket.assigns.current_user.id
  task_user = Repo.get_by!(TaskUser, task_id: task_id, user_id: user_id)

  # Just pass task_ids - user_id is inherited from task_user
  before_id = if before_id, do: String.to_integer(before_id)
  after_id = if after_id, do: String.to_integer(after_id)

  TaskUserOrder.move(task_user, between: {before_id, after_id})

  {:noreply, reload_tasks(socket)}
end
```

The library figures out that `task_id` is the "identity" field (primary key minus scope) and combines it with the `user_id` from the item being moved.

## Styling Drag States

Sortable.js adds CSS classes during drag operations. Configure Tailwind to use them:

**Tailwind v4 (`app.css`):**
```css
@custom-variant sortable-ghost (.sortable-ghost&, .sortable-ghost &);
@custom-variant sortable-chosen (.sortable-chosen&, .sortable-chosen &);
@custom-variant sortable-drag (.sortable-drag&, .sortable-drag &);
```

**Tailwind v3 (`tailwind.config.js`):**
```javascript
module.exports = {
  plugins: [
    plugin(function ({ addVariant }) {
      addVariant("sortable-ghost", [".sortable-ghost&", ".sortable-ghost &"]);
      addVariant("sortable-chosen", [".sortable-chosen&", ".sortable-chosen &"]);
      addVariant("sortable-drag", [".sortable-drag&", ".sortable-drag &"]);
    }),
  ],
};
```

Then style your items:

```heex
<li class="sortable-ghost:opacity-50 sortable-drag:shadow-lg">
  ...
</li>
```

## Additional Sortable Options

Pass Sortable.js options as `data-*` attributes (kebab-case):

```heex
<ul
  phx-hook="Sortable"
  data-on-end="reorder_todo"
  data-animation="150"
  data-delay="100"
  data-delay-on-touch-only
  data-handle=".drag-handle"
>
```

See the [Sortable.js documentation](https://github.com/SortableJS/Sortable#options) for all available options.
