defmodule ShowcagoServices.Jido.Actions.CreateVenueSourceAction do
  @moduledoc false
  use Jido.Action,
    name: "create_venue_source",
    description:
      "Creates a venue source record in the database, linking a source_key to a venue by its ID. " <>
        "Use get_venue first to look up the venue ID by name.",
    schema: [
      venue_id: [
        type: :pos_integer,
        required: true,
        doc: "The database ID of the venue (use get_venue to find it)"
      ],
      source_key: [
        type: :string,
        required: true,
        doc: "The unique source key identifier (e.g. \"salt_shed_ticketmaster\")"
      ],
      enabled: [
        type: :boolean,
        required: false,
        default: true,
        doc: "Whether the source is enabled for fetching"
      ]
    ]

  alias ShowcagoServices.Venues

  @impl true
  def run(%{venue_id: venue_id, source_key: source_key} = params, _context) do
    case Venues.get_venue(venue_id) do
      nil ->
        {:error, "Venue not found with ID: #{venue_id}"}

      venue ->
        attrs = %{
          "source_key" => source_key,
          "enabled" => Map.get(params, :enabled, true)
        }

        case Venues.create_venue_source(venue, attrs) do
          {:ok, venue_source} ->
            {:ok,
             %{
               id: venue_source.id,
               venue_id: venue_source.venue_id,
               source_key: venue_source.source_key,
               enabled: venue_source.enabled
             }}

          {:error, changeset} ->
            {:error, "Failed to create venue source: #{inspect(changeset.errors)}"}
        end
    end
  end
end
