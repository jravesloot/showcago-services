defmodule ShowcagoServices.Repo.Migrations.CreateArtists do
  use Ecto.Migration

  def change do
    create table(:artists) do
      add :name, :string, null: false
      add :website, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:artists, [:name])
  end
end
