defmodule TestOrder do
  use EctoOrderable.Order, repo: EctoOrderable.TestRepo

  import Ecto.Query

  @impl true
  def set_query(set, _opts) do
    where(Schemas.Item, set_id: ^set.id)
  end

  @impl true
  def set_query_for_item(item, _opts) do
    where(Schemas.Item, set_id: ^item.set_id)
  end

  @impl true
  def item_query(item, _opts) do
    where(Schemas.Item, set_id: ^item.set_id, id: ^item.id)
  end
end
