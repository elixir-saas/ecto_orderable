defmodule EctoOrderable.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_orderable,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp description() do
    "Add orderable sets with Ecto to your database."
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12", only: :test},
      {:postgrex, ">= 0.0.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  def aliases() do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
