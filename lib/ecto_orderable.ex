defmodule EctoOrderable do
  @moduledoc """
  Documentation for `EctoOrderable`.
  """

  alias EctoOrderable.Operations

  @doc """
  Returns the ordered index of the first child in the ordered series.
  """
  defdelegate first_order(order_struct), to: Operations

  @doc """
  Returns the ordered index of the last child in the ordered series.
  """
  defdelegate last_order(order_struct), to: Operations

  @doc """
  Returns the next ordered index, should be used for appending children.
  """
  defdelegate next_order(order_struct), to: Operations

  @doc """
  Returns the sibling immediately before an item in the set, `nil` if there is none.
  """
  defdelegate sibling_before(order_struct), to: Operations

  @doc """
  Returns the sibling immediately after an item in the set, `nil` if there is none.
  """
  defdelegate sibling_after(order_struct), to: Operations

  @doc """
  Moves an Order item in a set.

  ## Options

      * `:between` - Moves to between the items specified by a tuple `{before_id, after_id}`.
        Either may be `nil`, in the case that there is no previous or next item. If both are `nil`,
        it is assumed that the item being moved is the only item in the set, and its order will
        not be changed.
      * `:direction` - Moves one place in the set, either `:up` or `:down`.
  """
  defdelegate move(order_struct, opts), to: Operations
end
