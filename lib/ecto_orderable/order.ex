defmodule EctoOrderable.Order do
  @moduledoc """
  Defines an ordering module for a schema.

  ## Example

      defmodule TodoOrder do
        use EctoOrderable.Order,
          repo: MyApp.Repo,
          schema: Todo,
          scope: [:user_id]
      end

      # Get next order value for a new todo
      TodoOrder.next_order(user)
      TodoOrder.next_order(user_id: 123)

      # Reorder existing todo
      TodoOrder.move(todo, direction: :up)
      TodoOrder.move(todo, between: {id_above, id_below})

      # Query operations
      TodoOrder.first_order(todo)
      TodoOrder.last_order(user)
      TodoOrder.members(todo)

  ## Options

    * `:repo` - Required. The Ecto repo module.
    * `:schema` - Required. The Ecto schema module being ordered.
    * `:scope` - Required. List of fields that partition items into sets.
      Use `[]` for global ordering.
    * `:scope_join` - Optional. Keyword list mapping scope fields to joined schemas.
      Use when a scope field lives on a related table rather than the schema itself.
      Format: `[field: {JoinedSchema, :foreign_key}]` where `field` is the name of
      the scope field on `JoinedSchema`, and `:foreign_key` is the field on the
      current schema that references `JoinedSchema`.
    * `:order_field` - The field storing the order value. Defaults to `:position`.
    * `:order_increment` - The default spacing between items. Defaults to `1000.0`.

  ## Overriding members_query

  For complex filtering (soft deletes, status filters), override `members_query/2`:

      defmodule TodoOrder do
        use EctoOrderable.Order,
          repo: MyRepo,
          schema: Todo,
          scope: [:user_id]

        def members_query(query, _scope) do
          import Ecto.Query
          where(query, [t], is_nil(t.archived_at))
        end
      end

  ## Scope from Joined Tables

  When a scope field lives on a related table, use `:scope_join` to avoid
  denormalizing the field. The library will join to the related table automatically.

      # UserTaskPosition stores each user's ordering of tasks.
      # We want to scope by user_id (on UserTaskPosition) and status_id (on Task).

      defmodule UserTaskPositionOrder do
        use EctoOrderable.Order,
          repo: MyRepo,
          schema: UserTaskPosition,
          scope: [:user_id, :status_id],
          scope_join: [status_id: {Task, :task_id}]
      end

  The format is `[field: {JoinedSchema, :foreign_key}]`:
    * `field` - The scope field name, which exists on `JoinedSchema`
    * `JoinedSchema` - The schema to join to
    * `:foreign_key` - The field on the current schema that references `JoinedSchema`

  When passing an item struct, the joined association must be preloaded:

      position = Repo.preload(position, :task)
      UserTaskPositionOrder.move(position, direction: :up)

  See the "Scope from Joined Tables" guide for detailed examples.

  """

  @default_order_field :position
  @default_order_increment 1000.0

  defmacro __using__(opts) do
    repo = Keyword.get(opts, :repo) || raise "Must specify :repo"
    schema = Keyword.get(opts, :schema) || raise "Must specify :schema"
    scope = Keyword.get(opts, :scope) || raise "Must specify :scope (use [] for global)"
    scope_join = Keyword.get(opts, :scope_join, [])
    order_field = Keyword.get(opts, :order_field, @default_order_field)
    order_increment = Keyword.get(opts, :order_increment, @default_order_increment)

    quote do
      @repo unquote(repo)
      @schema unquote(schema)
      @scope unquote(scope)
      @scope_join unquote(scope_join)
      @order_field unquote(order_field)
      @order_increment unquote(order_increment)

      def __config__ do
        %{
          repo: @repo,
          schema: @schema,
          scope: @scope,
          scope_join: @scope_join,
          order_field: @order_field,
          order_increment: @order_increment,
          primary_key: @schema.__schema__(:primary_key)
        }
      end

      @doc """
      Returns an Ecto query for all members of the set.
      """
      def members(item_or_scope) do
        scope_values = resolve_scope(item_or_scope)
        query = EctoOrderable.Scope.apply(@schema, scope_values, @scope_join)
        members_query(query, scope_values)
      end

      @doc """
      Override this function to add additional filtering to the members query.
      """
      def members_query(query, _scope), do: query

      defoverridable members_query: 2

      @doc """
      Returns the order value of the first item in the set.
      """
      def first_order(item_or_scope \\ []) do
        config = build_config(item_or_scope)
        EctoOrderable.Operations.first_order(config)
      end

      @doc """
      Returns the order value of the last item in the set.
      """
      def last_order(item_or_scope \\ []) do
        config = build_config(item_or_scope)
        EctoOrderable.Operations.last_order(config)
      end

      @doc """
      Returns the next order value for appending a new item to the set.
      """
      def next_order(item_or_scope \\ []) do
        config = build_config(item_or_scope)
        EctoOrderable.Operations.next_order(config)
      end

      @doc """
      Returns the sibling immediately before the given item, or nil.
      """
      def sibling_before(item) do
        config = build_config(item)
        EctoOrderable.Operations.sibling_before(config)
      end

      @doc """
      Returns the sibling immediately after the given item, or nil.
      """
      def sibling_after(item) do
        config = build_config(item)
        EctoOrderable.Operations.sibling_after(config)
      end

      @doc """
      Moves an item within its set.

      ## Options

        * `:between` - Tuple `{before_id, after_id}`. Either may be nil.
        * `:direction` - Either `:up` or `:down`.

      """
      def move(item, opts) do
        config = build_config(item)
        EctoOrderable.Operations.move(config, opts)
      end

      @doc """
      Returns the count of items in the set.
      """
      def count(item_or_scope \\ []) do
        config = build_config(item_or_scope)
        EctoOrderable.Operations.count(config)
      end

      @doc """
      Checks if the set needs rebalancing due to order values being too close together.

      Returns `true` if any two adjacent items have a difference less than the threshold.

      ## Options

        * `:threshold` - Minimum acceptable difference between adjacent items.
          Defaults to `0.001`.

      ## Examples

          if TodoOrder.needs_rebalance?(user) do
            TodoOrder.rebalance(user)
          end

      """
      def needs_rebalance?(item_or_scope \\ [], opts \\ []) do
        config = build_config(item_or_scope)
        EctoOrderable.Operations.needs_rebalance?(config, opts)
      end

      @doc """
      Rebalances the order values for all items in a set to evenly spaced increments.

      Useful for:
      - Rebalancing after many fractional insertions have made values too close
      - Initializing order values when adding ordering to existing records

      ## Options

        * `:order_by` - Field (or `{direction, field}` tuple) to sort by when
          determining new positions. Defaults to the order field. Use a different
          field (e.g., `:inserted_at`) when initializing ordering for the first time.

      ## Examples

          # Rebalance based on current order
          TodoOrder.rebalance(user)

          # Initialize based on creation time (oldest first)
          TodoOrder.rebalance(user, order_by: :inserted_at)

          # Initialize based on creation time (newest first)
          TodoOrder.rebalance(user, order_by: {:desc, :inserted_at})

          # For global sets
          TemplateOrder.rebalance()

      """
      def rebalance(item_or_scope \\ [], opts \\ []) do
        config = build_config(item_or_scope)
        EctoOrderable.Operations.rebalance(config, opts)
      end

      # Private helpers

      defp build_config(item_or_scope) do
        scope_values = resolve_scope(item_or_scope)
        item = if is_struct(item_or_scope, @schema), do: item_or_scope, else: nil

        %{
          repo: @repo,
          schema: @schema,
          scope: @scope,
          scope_join: @scope_join,
          scope_values: scope_values,
          order_field: @order_field,
          order_increment: @order_increment,
          primary_key: @schema.__schema__(:primary_key),
          item: item,
          members_query_fn: &members/1
        }
      end

      defp resolve_scope(item_or_scope) do
        EctoOrderable.Scope.resolve(item_or_scope, @schema, @scope, @scope_join)
      end
    end
  end
end
