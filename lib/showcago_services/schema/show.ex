defmodule ShowcagoServices.Schema.Show do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses [:upcoming, :postponed, :cancelled, :past]

  def statuses, do: @statuses

  schema "shows" do
    field :date, :utc_datetime
    field :doors_open, :time
    field :show_time, :time
    field :ticket_url, :string
    field :price_min, :decimal
    field :price_max, :decimal
    field :ignored, :boolean, default: false
    field :status, Ecto.Enum, values: @statuses, default: :upcoming
    field :notes, :string

    belongs_to :venue, ShowcagoServices.Schema.Venue

    many_to_many :artists, ShowcagoServices.Schema.Artist,
      join_through: "show_artists",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(show, attrs) do
    show
    |> cast(attrs, [
      :date,
      :doors_open,
      :show_time,
      :ticket_url,
      :price_min,
      :price_max,
      :ignored,
      :status,
      :notes,
      :venue_id
    ])
    |> validate_required([:date, :venue_id])
    |> validate_number(:price_min, greater_than_or_equal_to: 0)
    |> validate_number(:price_max, greater_than_or_equal_to: 0)
    |> check_constraint(:status, name: :shows_status_valid)
    |> foreign_key_constraint(:venue_id)
  end
end
