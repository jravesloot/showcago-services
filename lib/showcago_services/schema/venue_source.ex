defmodule ShowcagoServices.Schema.VenueSource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "venue_sources" do
    field :source_key, :string
    field :raw_payload, :string
    field :payload_format, :string
    field :fetched_at, :utc_datetime
    field :enabled, :boolean, default: true
    field :last_error, :string

    belongs_to :venue, ShowcagoServices.Schema.Venue

    timestamps(type: :utc_datetime)
  end

  def changeset(venue_source, attrs) do
    venue_source
    |> cast(attrs, [
      :venue_id,
      :source_key,
      :raw_payload,
      :payload_format,
      :fetched_at,
      :enabled,
      :last_error
    ])
    |> validate_required([:venue_id, :source_key])
    |> unique_constraint([:venue_id, :source_key])
  end
end
