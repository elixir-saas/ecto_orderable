defmodule EctoOrderable.Query do
  @moduledoc """
  Helpers for querying position information for items in an ordered set.
  """

  @doc """
  Given an interpolated Orderable and an Ecto query term representing an orderable row,
  returns a boolean indicating if the row is first in the sequence.
  """
  defmacro first_in_order?({:^, _, [order]}, row) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN true ELSE false END",
        field(unquote(row), ^unquote(order).order_field),
        ^EctoOrderable.first_order(unquote(order))
      )
    end
  end

  defmacro first_in_order?(order, _row) do
    raise "Unbound variable `#{Macro.to_string(order)}` in query. If you are attempting to interpolate a value, use ^var"
  end

  @doc """
  Given an interpolated Orderable and an Ecto query term representing an orderable row,
  returns a boolean indicating if the row is last in the sequence.
  """
  defmacro last_in_order?({:^, _, [order]}, row) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN true ELSE false END",
        field(unquote(row), ^unquote(order).order_field),
        ^EctoOrderable.last_order(unquote(order))
      )
    end
  end

  defmacro last_in_order?(order, _row) do
    raise "Unbound variable `#{Macro.to_string(order)}` in query. If you are attempting to interpolate a value, use ^var"
  end
end
