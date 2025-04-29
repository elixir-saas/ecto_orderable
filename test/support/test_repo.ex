defmodule EctoOrderable.TestRepo do
  use Ecto.Repo,
    otp_app: :ecto_orderable,
    adapter: Ecto.Adapters.Postgres
end
