defmodule EctoOrderable.Order do
  @moduledoc """

      defmodule TaskOrder do
        use EctoOrderable.Order,
          repo: MyApp.Repo,
          order_field: :order_index,
          order_increment: 1000.0

        def set_query(organization, opts) do
          ...
        end

        def set_query_for_item(task, opts) do
          ...
        end

        def item_query(task, opts) do
          ...
        end
      end

      TaskOrder.set(organization) |> EctoOrderable.first_order()

      TaskOrder.set(organization) |> EctoOrderable.last_order()

      TaskOrder.set(organization) |> EctoOrderable.next_order()

      TaskOrder.item(task) |> EctoOrderable.move(:up)

      TaskOrder.item(task) |> EctoOrderable.current_order()

      TaskOrder.item(task) |> EctoOrderable.insert(:up)

      TaskOrder.item(task) |> EctoOrderable.reposition(1000.0)

      TaskOrder.item(task) |> EctoOrderable.reposition(1000.0)

  """

  @type order() :: %{
          schema: {:set, struct()} | {:item, struct()},
          repo: module(),
          order_field: atom(),
          order_increment: float()
        }

  @doc """
  Given a struct that represents a container for the set of all items in an OrderableSet,
  must return a query that filters for all the items in the set.
  """
  @callback set_query(struct()) :: Ecto.Query.t()

  @doc """
  Given a struct that represents an item in an OrderableSet, must return a query that filters
  for all the items in the set.
  """
  @callback set_query_for_item(struct()) :: Ecto.Query.t()

  @doc """
  Given a struct that represents an item in an OrderableSet, must return a query that filters
  for this specific item in the set.
  """
  @callback item_query(struct()) :: Ecto.Query.t()

  @default_order_field :order_index
  @default_order_increment 1000.0

  defmacro __using__(opts) do
    repo = Keyword.get(opts, :repo) || raise "Must specify :repo when using OrderableSet"

    order_field = Keyword.get(opts, :order_field, @default_order_field)
    order_increment = Keyword.get(opts, :order_increment, @default_order_increment)

    quote do
      @behaviour unquote(__MODULE__)

      defstruct [
        :schema,
        repo: unquote(repo),
        order_field: unquote(order_field),
        order_increment: unquote(order_increment)
      ]

      def set(set_schema) do
        %__MODULE__{schema: {:set, set_schema}}
      end

      def item(item_schema) do
        %__MODULE__{schema: {:item, item_schema}}
      end
    end
  end
end
