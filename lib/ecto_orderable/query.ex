defmodule EctoOrderable.Query do
  @doc """
  Given an interpolated Orderable and an Ecto query term representing an orderable row,
  returns a boolean indicating if the row is first in the sequence.
  """
  defmacro is_first_query({:^, _, [orderable]}, row) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN true ELSE false END",
        field(unquote(row), unquote(orderable.order_field)),
        ^EctoOrderable.first_order(unquote(orderable))
      )
    end
  end

  defmacro is_first_query(orderable, _row) do
    raise "Unbound variable `#{Macro.to_string(orderable)}` in query. If you are attempting to interpolate a value, use ^var"
  end

  @doc """
  Given an interpolated Orderable and an Ecto query term representing an orderable row,
  returns a boolean indicating if the row is last in the sequence.
  """
  defmacro is_last_query({:^, _, [orderable]}, row) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN true ELSE false END",
        field(unquote(row), unquote(orderable.order_field)),
        ^EctoOrderable.last_order(unquote(orderable))
      )
    end
  end

  defmacro is_last_query(orderable, _row) do
    raise "Unbound variable `#{Macro.to_string(orderable)}` in query. If you are attempting to interpolate a value, use ^var"
  end
end
