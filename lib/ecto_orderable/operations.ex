defmodule EctoOrderable.Operations do
  @moduledoc false
  import Ecto.Query

  def first_order(order_struct) do
    order_struct
    |> set_query()
    |> select([o], coalesce(min(field(o, ^order_struct.order_field)), 0.0))
    |> order_struct.repo.one!()
  end

  def last_order(order_struct) do
    order_struct
    |> set_query()
    |> select([o], coalesce(max(field(o, ^order_struct.order_field)), 0.0))
    |> order_struct.repo.one!()
  end

  def next_order(order_struct) do
    last_order(order_struct) + order_struct.order_increment
  end

  def sibling_before(order_struct) do
    current_order = current_order(order_struct)

    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) < ^current_order,
        order_by: {:desc, field(o, ^order_struct.order_field)},
        limit: 1
      )

    order_struct.repo.one(query)
  end

  def sibling_after(order_struct) do
    current_order = current_order(order_struct)

    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) > ^current_order,
        order_by: {:asc, field(o, ^order_struct.order_field)},
        limit: 1
      )

    order_struct.repo.one(query)
  end

  def move(order_struct, opts) do
    next_order =
      cond do
        between_opt = opts[:between] ->
          next_order_between(order_struct, between_opt)

        direction_opt = opts[:direction] ->
          next_order_direction(order_struct, direction_opt)

        true ->
          raise "Must provide one of :between, :direction to move/2"
      end

    if next_order do
      item_query = item_query(order_struct)
      order_struct.repo.update_all(item_query, set: [{order_struct.order_field, next_order}])
    end

    extract(order_struct, next_order)
  end

  ## Internal

  defp next_order_between(order_struct, {before_id, after_id}) do
    before_order = select_order(order_struct, before_id)
    after_order = select_order(order_struct, after_id)

    case {before_order, after_order} do
      {nil, nil} -> nil
      {nil, after_order} -> after_order - order_struct.order_increment
      {before_order, nil} -> before_order + order_struct.order_increment
      {before_order, after_order} -> (before_order + after_order) / 2
    end
  end

  defp next_order_direction(order_struct, :up) do
    current_order = current_order(order_struct)

    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) < ^current_order,
        order_by: {:desc, field(o, ^order_struct.order_field)},
        select: field(o, ^order_struct.order_field),
        limit: 2
      )

    case order_struct.repo.all(query) do
      [] -> nil
      [prev_order] -> prev_order - order_struct.order_increment
      [prev_order, prev_prev_order] -> (prev_order + prev_prev_order) / 2
    end
  end

  defp next_order_direction(order_struct, :down) do
    current_order = current_order(order_struct)

    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) > ^current_order,
        order_by: {:asc, field(o, ^order_struct.order_field)},
        select: field(o, ^order_struct.order_field),
        limit: 2
      )

    case order_struct.repo.all(query) do
      [] -> nil
      [next_order] -> next_order + order_struct.order_increment
      [next_order, next_next_order] -> (next_order + next_next_order) / 2
    end
  end

  def current_order(order_struct) do
    item_query = item_query(order_struct)
    order_struct.repo.one!(select(item_query, [o], field(o, ^order_struct.order_field)))
  end

  defp select_order(_order_struct, _item_id = nil), do: nil

  defp select_order(order_struct, item_id) do
    set_query = set_query(order_struct)
    query = select(set_query, [o], field(o, ^order_struct.order_field))
    order_struct.repo.get!(query, item_id)
  end

  defp set_query(%module{context: {:set, set_struct}, opts: opts}) do
    module.set_query(set_struct, opts)
  end

  defp set_query(%module{context: {:item, item_struct}, opts: opts}) do
    module.set_query_for_item(item_struct, opts)
  end

  defp item_query(%_module{context: {:set, _set_struct}}) do
    raise "Cannot generate item_query when only the set struct is provided"
  end

  defp item_query(%module{context: {:item, item_struct}, opts: opts}) do
    module.item_query(item_struct, opts)
  end

  defp extract(%_module{context: {:item, item_struct}}, _order_index = nil) do
    item_struct
  end

  defp extract(%_module{context: {:item, item_struct}} = order_struct, order_index) do
    Map.put(item_struct, order_struct.order_field, order_index)
  end
end
