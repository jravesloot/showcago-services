defmodule ShowcagoServices.Events.Artist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "artists" do
    field :name, :string
    field :website, :string

    many_to_many :shows, ShowcagoServices.Events.Show, join_through: "show_artists"

    timestamps(type: :utc_datetime)
  end

  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name, :website])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
