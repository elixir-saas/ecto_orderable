defmodule EctoOrderable.TestRepo.Migrations.CreateSetsAndItems do
  use Ecto.Migration

  def change do
    create table(:sets)

    create table(:items) do
      add :set_id, references(:sets), null: false
      add :order_index, :float, null: false
    end
  end
end
