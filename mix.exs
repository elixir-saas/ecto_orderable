defmodule EctoOrderable.MixProject do
  use Mix.Project

  @source_url "https://github.com/elixir-saas/ecto_orderable"
  @version "0.1.0"

  def project do
    [
      app: :ecto_orderable,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      name: "Ecto Orderable",
      docs: docs()
    ]
  end

  defp description() do
    """
    Flexible ordering for Ecto schemas. Supports belongs-to, many-to-many, and global
    sets with fractional indexing for efficient reordering. Integrates with Phoenix
    LiveView and Sortable.js for drag-and-drop interfaces.
    """
  end

  defp package() do
    [
      maintainers: ["Justin Tormey"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib guides .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
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

  defp docs do
    [
      main: "getting-started",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      source_url: @source_url,
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  def extras() do
    [
      "guides/introduction/Getting Started.md",
      "guides/howtos/Belongs-To Sets.md",
      "guides/howtos/Multi-Scope Sets.md",
      "guides/howtos/Many-To-Many Sets.md",
      "guides/howtos/Global Sets.md",
      "guides/howtos/Phoenix LiveView Integration.md"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      "How-To's": ~r/guides\/howtos\/.?/
    ]
  end

  def aliases() do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
