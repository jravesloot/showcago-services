defmodule ShowcagoServices.Schema.Venue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "venues" do
    field :name, :string
    field :address, :string
    field :city, :string
    field :state, :string
    field :zip_code, :string
    field :website, :string
    field :schedule_html, :string
    field :data_last_collected, :utc_datetime

    has_many :shows, ShowcagoServices.Schema.Show

    timestamps(type: :utc_datetime)
  end

  def changeset(venue, attrs) do
    venue
    |> cast(attrs, [
      :name,
      :address,
      :city,
      :state,
      :zip_code,
      :website,
      :schedule_html,
      :data_last_collected
    ])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> maybe_set_data_last_collected()
  end

  defp maybe_set_data_last_collected(changeset) do
    if Map.has_key?(changeset.changes, :schedule_html) do
      put_change(changeset, :data_last_collected, DateTime.utc_now(:second))
    else
      changeset
    end
  end
end
