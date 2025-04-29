import Config

config :ecto_orderable,
  ecto_repos: [EctoOrderable.TestRepo]

config :ecto_orderable, EctoOrderable.TestRepo,
  username: "postgres",
  password: "postgres",
  database: "ecto_orderable_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :logger, level: :warning
