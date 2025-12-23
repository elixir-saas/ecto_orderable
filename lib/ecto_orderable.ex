defmodule EctoOrderable do
  @moduledoc """
  Provides ordering for Ecto schemas within well-defined sets.

  ## Usage

      defmodule TodoOrder do
        use EctoOrderable,
          repo: MyApp.Repo,
          schema: Todo,
          scope: [:user_id]
      end

      # Get next order value for a new todo
      order = TodoOrder.next_order(user)
      Repo.insert!(%Todo{title: "Buy milk", user_id: user.id, order_index: order})

      # Reorder existing items
      TodoOrder.move(todo, direction: :up)
      TodoOrder.move(todo, between: {id_above, id_below})

  See `EctoOrderable.Order` for full documentation and options.
  """

  defmacro __using__(opts) do
    quote do
      use EctoOrderable.Order, unquote(opts)
    end
  end
end
