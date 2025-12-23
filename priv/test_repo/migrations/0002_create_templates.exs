defmodule EctoOrderable.TestRepo.Migrations.CreateTemplates do
  use Ecto.Migration

  def change do
    create table(:templates) do
      add :name, :string
      add :order_index, :float
    end
  end
end
