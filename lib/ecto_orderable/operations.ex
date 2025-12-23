defmodule EctoOrderable.Operations do
  @moduledoc false
  import Ecto.Query

  @default_rebalance_threshold 0.001

  def first_order(config) do
    config
    |> members_query()
    |> select([o], coalesce(min(field(o, ^config.order_field)), 0.0))
    |> config.repo.one!()
  end

  def last_order(config) do
    config
    |> members_query()
    |> select([o], coalesce(max(field(o, ^config.order_field)), 0.0))
    |> config.repo.one!()
  end

  def next_order(config) do
    last_order(config) + config.order_increment
  end

  def count(config) do
    config
    |> members_query()
    |> select([o], count())
    |> config.repo.one!()
  end

  def needs_rebalance?(config, opts) do
    threshold = Keyword.get(opts, :threshold, @default_rebalance_threshold)

    orders =
      members_query(config)
      |> order_by([o], field(o, ^config.order_field))
      |> select([o], field(o, ^config.order_field))
      |> config.repo.all()

    case orders do
      [] ->
        false

      [_] ->
        false

      _ ->
        orders
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.any?(fn [a, b] -> b - a < threshold end)
    end
  end

  def sibling_before(config) do
    current_order = current_order(config)

    query =
      from(o in members_query(config),
        where: field(o, ^config.order_field) < ^current_order,
        order_by: {:desc, field(o, ^config.order_field)},
        limit: 1
      )

    config.repo.one(query)
  end

  def sibling_after(config) do
    current_order = current_order(config)

    query =
      from(o in members_query(config),
        where: field(o, ^config.order_field) > ^current_order,
        order_by: {:asc, field(o, ^config.order_field)},
        limit: 1
      )

    config.repo.one(query)
  end

  def move(config, opts) do
    unless config.item do
      raise ArgumentError, "move/2 requires an item struct"
    end

    next_order =
      cond do
        between_opt = opts[:between] ->
          next_order_between(config, between_opt)

        direction_opt = opts[:direction] ->
          next_order_direction(config, direction_opt)

        true ->
          raise ArgumentError, "Must provide one of :between, :direction to move/2"
      end

    if next_order do
      item_query = item_query(config)
      config.repo.update_all(item_query, set: [{config.order_field, next_order}])
    end

    extract(config, next_order)
  end

  def rebalance(config, opts) do
    order_by_opt = Keyword.get(opts, :order_by, config.order_field)

    # Fetch all primary keys in desired order
    items =
      members_query(config)
      |> apply_order_by(order_by_opt)
      |> select([o], map(o, ^config.primary_key))
      |> config.repo.all()

    case items do
      [] ->
        {:ok, 0}

      items ->
        do_rebalance(config, items)
        {:ok, length(items)}
    end
  end

  ## Internal

  defp do_rebalance(config, items) do
    config.repo.transaction(fn ->
      items
      |> Enum.with_index(1)
      |> Enum.each(fn {pk_map, index} ->
        new_order = index * config.order_increment

        members_query(config)
        |> where_primary_key(config.primary_key, pk_map)
        |> config.repo.update_all(set: [{config.order_field, new_order}])
      end)
    end)
  end

  defp apply_order_by(query, {direction, field}) when direction in [:asc, :desc] do
    order_by(query, [o], [{^direction, field(o, ^field)}])
  end

  defp apply_order_by(query, field) when is_atom(field) do
    order_by(query, [o], field(o, ^field))
  end

  defp next_order_between(config, {before_id, after_id}) do
    before_order = select_order(config, before_id)
    after_order = select_order(config, after_id)

    case {before_order, after_order} do
      {nil, nil} -> nil
      {nil, after_order} -> after_order - config.order_increment
      {before_order, nil} -> before_order + config.order_increment
      {before_order, after_order} -> (before_order + after_order) / 2
    end
  end

  defp next_order_direction(config, :up) do
    current_order = current_order(config)

    query =
      from(o in members_query(config),
        where: field(o, ^config.order_field) < ^current_order,
        order_by: {:desc, field(o, ^config.order_field)},
        select: field(o, ^config.order_field),
        limit: 2
      )

    case config.repo.all(query) do
      [] -> nil
      [prev_order] -> prev_order - config.order_increment
      [prev_order, prev_prev_order] -> (prev_order + prev_prev_order) / 2
    end
  end

  defp next_order_direction(config, :down) do
    current_order = current_order(config)

    query =
      from(o in members_query(config),
        where: field(o, ^config.order_field) > ^current_order,
        order_by: {:asc, field(o, ^config.order_field)},
        select: field(o, ^config.order_field),
        limit: 2
      )

    case config.repo.all(query) do
      [] -> nil
      [next_order] -> next_order + config.order_increment
      [next_order, next_next_order] -> (next_order + next_next_order) / 2
    end
  end

  defp current_order(config) do
    item_query = item_query(config)
    config.repo.one!(select(item_query, [o], field(o, ^config.order_field)))
  end

  defp select_order(_config, nil), do: nil

  defp select_order(config, item_id) do
    # Resolve item_id to a full primary key map if needed
    resolved_id = resolve_item_id(config, item_id)

    members_query(config)
    |> where_primary_key(config.primary_key, resolved_id)
    |> select([o], field(o, ^config.order_field))
    |> config.repo.one!()
  end

  # For composite keys with a simple value, inherit scope from the item being moved
  defp resolve_item_id(config, item_id) when not is_map(item_id) do
    identity_fields = config.primary_key -- config.scope

    case identity_fields do
      # Single identity field - use the passed value directly
      [identity_field] when length(config.primary_key) > 1 ->
        # Build full primary key by combining identity value with scope from item
        scope_values =
          config.scope
          |> Enum.map(fn field -> {field, Map.fetch!(config.item, field)} end)
          |> Map.new()

        Map.put(scope_values, identity_field, item_id)

      # Simple primary key or multiple identity fields - use as-is
      _ ->
        item_id
    end
  end

  defp resolve_item_id(_config, item_id) when is_map(item_id) do
    item_id
  end

  defp where_primary_key(query, [pk_field], id) when not is_map(id) do
    where(query, [o], field(o, ^pk_field) == ^id)
  end

  defp where_primary_key(query, pk_fields, id) when is_map(id) do
    Enum.reduce(pk_fields, query, fn pk_field, q ->
      value = Map.fetch!(id, pk_field)
      where(q, [o], field(o, ^pk_field) == ^value)
    end)
  end

  defp members_query(config) do
    config.members_query_fn.(config.item || config.scope_values)
  end

  defp item_query(config) do
    unless config.item do
      raise ArgumentError, "Cannot generate item_query without an item"
    end

    pk_values =
      config.primary_key
      |> Enum.map(fn pk_field -> {pk_field, Map.fetch!(config.item, pk_field)} end)

    Enum.reduce(pk_values, members_query(config), fn {pk_field, value}, q ->
      where(q, [o], field(o, ^pk_field) == ^value)
    end)
  end

  defp extract(config, nil) do
    config.item
  end

  defp extract(config, new_position) do
    Map.put(config.item, config.order_field, new_position)
  end
end
