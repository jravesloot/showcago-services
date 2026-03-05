defmodule ShowcagoServices.Repo.Migrations.AddRoleToUsers do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "user"
    end

    create index(:users, [:role])
  end
end
