defmodule ShowcagoServices.Jido.Actions.GetVenueAction do
  @moduledoc false
  use Jido.Action,
    name: "get_venue",
    description: "Looks up a venue by name and returns its details including ID.",
    schema: [
      venue_name: [
        type: :string,
        required: true,
        doc: "The name of the venue to look up (e.g. \"Salt Shed\")"
      ]
    ]

  alias ShowcagoServices.Venues

  @impl true
  def run(%{venue_name: venue_name}, _context) do
    case Venues.get_venue_by_name(venue_name) do
      nil ->
        {:error, "Venue not found: #{venue_name}"}

      venue ->
        {:ok,
         %{
           id: venue.id,
           name: venue.name,
           address: venue.address,
           city: venue.city,
           state: venue.state,
           zip_code: venue.zip_code,
           website: venue.website
         }}
    end
  end
end
