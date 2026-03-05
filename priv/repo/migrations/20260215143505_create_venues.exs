defmodule ShowcagoServices.Repo.Migrations.CreateVenues do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:venues) do
      add :name, :string, null: false
      add :address, :string
      add :city, :string
      add :state, :string
      add :zip_code, :string
      add :website, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:venues, [:name])
  end
end
