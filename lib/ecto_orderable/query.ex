defmodule EctoOrderable.Query do
  @moduledoc """
  Helpers for querying position information for items in an ordered set.

  ## Checking Position in Queries

  To check if an item is first or last in its set, compute the boundary value
  and compare directly:

      first_order = TodoOrder.first_order(user)
      last_order = TodoOrder.last_order(user)

      from(t in Todo,
        where: t.user_id == ^user.id,
        select: %{
          todo: t,
          is_first: t.position == ^first_order,
          is_last: t.position == ^last_order
        }
      )

  ## Using the Macros

  For convenience, you can use the `first_in_set?/3` and `last_in_set?/3` macros
  which handle the comparison as a SQL fragment:

      import EctoOrderable.Query

      from(t in Todo,
        where: t.user_id == ^user.id,
        select: %{
          todo: t,
          is_first: first_in_set?(TodoOrder, ^user, t),
          is_last: last_in_set?(TodoOrder, ^user, t)
        }
      )

  """

  @doc """
  Returns a SQL fragment that evaluates to true if the row is first in its set.

  ## Parameters

    * `order_module` - The order module (e.g., `TodoOrder`)
    * `scope` - The scope, must be interpolated with `^` (e.g., `^user` or `^[user_id: 1]`)
    * `row` - The query binding for the row being checked

  ## Example

      from(t in Todo,
        select: %{todo: t, is_first: first_in_set?(TodoOrder, ^user, t)}
      )

  """
  defmacro first_in_set?(order_module, {:^, _, [scope]}, row) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN true ELSE false END",
        field(unquote(row), ^unquote(order_module).__config__().order_field),
        ^unquote(order_module).first_order(unquote(scope))
      )
    end
  end

  defmacro first_in_set?(_order_module, scope, _row) do
    raise "Unbound variable `#{Macro.to_string(scope)}` in query. Use ^var to interpolate the scope."
  end

  @doc """
  Returns a SQL fragment that evaluates to true if the row is last in its set.

  ## Parameters

    * `order_module` - The order module (e.g., `TodoOrder`)
    * `scope` - The scope, must be interpolated with `^` (e.g., `^user` or `^[user_id: 1]`)
    * `row` - The query binding for the row being checked

  ## Example

      from(t in Todo,
        select: %{todo: t, is_last: last_in_set?(TodoOrder, ^user, t)}
      )

  """
  defmacro last_in_set?(order_module, {:^, _, [scope]}, row) do
    quote do
      fragment(
        "CASE WHEN ? = ? THEN true ELSE false END",
        field(unquote(row), ^unquote(order_module).__config__().order_field),
        ^unquote(order_module).last_order(unquote(scope))
      )
    end
  end

  defmacro last_in_set?(_order_module, scope, _row) do
    raise "Unbound variable `#{Macro.to_string(scope)}` in query. Use ^var to interpolate the scope."
  end
end
