defmodule ShowcagoServices.Events.Venue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "venues" do
    field :name, :string
    field :address, :string
    field :city, :string
    field :state, :string
    field :zip_code, :string
    field :website, :string

    has_many :shows, ShowcagoServices.Events.Show

    timestamps(type: :utc_datetime)
  end

  def changeset(venue, attrs) do
    venue
    |> cast(attrs, [:name, :address, :city, :state, :zip_code, :website])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
