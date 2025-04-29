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
end
