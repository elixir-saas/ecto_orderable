defmodule EctoOrderable.RepoCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias EctoOrderable.TestRepo

      import Ecto
      import Ecto.Query
      import EctoOrderable.RepoCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(EctoOrderable.TestRepo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
