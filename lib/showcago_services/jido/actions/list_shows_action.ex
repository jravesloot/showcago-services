defmodule ShowcagoServices.Jido.Actions.ListShowsAction do
  require Logger
  @max_shows 20
  @chicago_time_zone "America/Chicago"

  use Jido.Action,
    name: "list_shows",
    description: "Lists upcoming shows in Chicago with details like date, venue, and artists."

  @impl true
  def run(_params, _context) do
    # sending the raw data seems to stringify it somewhere, truncating the shows list
    shows =
      ShowcagoServices.Shows.list_upcoming_shows(show_ignored: false)
      |> Enum.take(@max_shows)
      |> format_shows_response()

    {:ok, %{shows: shows}}
  end

  # taken from TelegramBot module, TODO: refactor
  defp format_shows_response([]) do
    "No upcoming shows found right now."
  end

  defp format_shows_response(shows) do
    lines =
      Enum.map(shows, fn show ->
        title = show.notes || "Untitled event"
        venue_name = (show.venue && show.venue.name) || "Unknown venue"
        artists = show.artists |> Enum.map(& &1.name) |> Enum.join(", ")

        [
          "date:#{format_show_datetime(show.date)}",
          "title:#{title}",
          "artists:#{artists}",
          "show_id:#{show.id}",
          "venue:#{venue_name}"
        ]
        |> Enum.join("\t")
      end)

    # Enum.join(["Upcoming shows:", "" | lines], "\n")
    Enum.join(lines, "\n")
  end

  defp format_show_datetime(%DateTime{} = datetime) do
    datetime
    |> chicago_datetime()
    |> Calendar.strftime("%a, %b %-d %I:%M %p CT")
  end

  defp chicago_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted_datetime} -> shifted_datetime
      _ -> datetime
    end
  end
end
