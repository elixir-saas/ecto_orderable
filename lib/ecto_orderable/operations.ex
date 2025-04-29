defmodule EctoOrderable.Operations do
  @moduledoc false
  import Ecto.Query

  def first_order(order_struct) do
    order_struct
    |> set_query()
    |> select([o], coalesce(min(field(o, ^order_struct.order_field)), 0))
    |> order_struct.repo.one!()
  end

  def last_order(order_struct) do
    order_struct
    |> set_query()
    |> select([o], coalesce(max(field(o, ^order_struct.order_field)), 0))
    |> order_struct.repo.one!()
  end

  def next_order(order_struct) do
    last_order(order_struct) + order_struct.order_increment
  end

  def move(order_struct, dir, opts \\ []) do
    type = Keyword.get(opts, :type, :move)

    current_order = current_order(order_struct)

    next_order = move_order(order_struct, current_order, dir, type)

    if next_order != current_order do
      item_query = item_query(order_struct)
      order_struct.repo.update_all(item_query, set: [{order_struct.order_field, next_order}])
    end

    :ok
  end

  def current_order(order_struct) do
    item_query = item_query(order_struct)
    order_struct.repo.one!(select(item_query, [o], field(o, ^order_struct.order_field)))
  end

  def move_order(order_struct, current_order, :up, :move) do
    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) < ^current_order,
        order_by: {:desc, field(o, ^order_struct.order_field)},
        select: field(o, ^order_struct.order_field),
        limit: 2
      )

    case order_struct.repo.all(query) do
      [] -> current_order
      [prev_order] -> prev_order / 2
      [prev_order, prev_prev_order] -> (prev_order + prev_prev_order) / 2
    end
  end

  def move_order(order_struct, current_order, :down, :move) do
    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) > ^current_order,
        order_by: {:asc, field(o, ^order_struct.order_field)},
        select: field(o, ^order_struct.order_field),
        limit: 2
      )

    case order_struct.repo.all(query) do
      [] -> current_order
      [next_order] -> next_order + order_struct.order_increment
      [next_order, next_next_order] -> (next_order + next_next_order) / 2
    end
  end

  def move_order(order_struct, current_order, :up, :insert) do
    case find_closest_sibling(order_struct, current_order, :prev) do
      nil -> current_order - order_struct.order_increment
      prev_order -> (current_order + prev_order.order_index) / 2
    end
  end

  def move_order(order_struct, current_order, :down, :insert) do
    case find_closest_sibling(order_struct, current_order, :next) do
      nil -> current_order + order_struct.order_increment
      next_order -> (current_order + next_order.order_index) / 2
    end
  end

  def insert(order_struct, new_order_struct, dir) do
    current_order = current_order(order_struct)

    move_position = move_order(order_struct, current_order, dir, :insert)

    item_query = item_query(new_order_struct)

    order_struct.repo.update_all(item_query, set: [{order_struct.order_field, move_position}])
  end

  def reposition(order_struct, order_index) do
    item_query = item_query(order_struct)

    order_struct.repo.update_all(item_query,
      set: [{order_struct.order_field, order_index * order_struct.order_increment}]
    )
  end

  def find_closest_sibling(order_struct, current_order, :prev) do
    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) < ^current_order,
        order_by: {:desc, field(o, ^order_struct.order_field)},
        limit: 1
      )

    order_struct.repo.one(query)
  end

  def find_closest_sibling(order_struct, current_order, :next) do
    query =
      from(o in set_query(order_struct),
        where: field(o, ^order_struct.order_field) > ^current_order,
        order_by: {:asc, field(o, ^order_struct.order_field)},
        limit: 1
      )

    order_struct.repo.one(query)
  end

  def get_page(order_struct, page_size) do
    # Get the order_index of the item with the given id.
    item_query = item_query(order_struct)

    order_index =
      order_struct.repo.one!(select(item_query, [o], field(o, ^order_struct.order_field)))

    # Count the number of items with a smaller order_index.
    count_query =
      order_struct
      |> set_query()
      |> where([o], field(o, ^order_struct.order_field) < ^order_index)
      |> select([o], count(o.id))

    preceding_items_count = order_struct.repo.one!(count_query)

    # Calculate the page number.
    page_number = div(preceding_items_count, page_size) + 1

    page_number
  end

  ## Internal

  defp set_query(%module{schema: {:set, struct}}) do
    module.set_query(struct)
  end

  defp set_query(%module{schema: {:item, struct}}) do
    module.set_query_for_item(struct)
  end

  defp item_query(%_module{schema: {:set, _struct}}) do
    raise "Cannot generate item_query when only the set struct is provided"
  end

  defp item_query(%module{schema: {:item, struct}}) do
    module.item_query(struct)
  end
end
