defmodule ShowcagoServices.Venues.Sources.SaltShedTicketmaster do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source
  alias ShowcagoServices.Venues.Sources.HtmlLdJson

  require Logger

  @default_refresh_interval_seconds 3_600
  @salt_shed_tm_urls [
    "https://app.ticketmaster.com/discovery/v2/events.json?size=200&apikey=VlcOb6C2Y4W0iGius6pFX1Gh7a9GnKyg&venueId=KovZ917AI5F",
    "https://app.ticketmaster.com/discovery/v2/events.json?size=200&apikey=VlcOb6C2Y4W0iGius6pFX1Gh7a9GnKyg&venueId=KovZ917Amf0"
  ]

  @impl true
  def source_key, do: "salt_shed_ticketmaster"

  @impl true
  def venue_name, do: "The Salt Shed"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_ticketmaster_events_fun =
      Keyword.get(opts, :fetch_ticketmaster_events_fun, &fetch_salt_shed_ticketmaster_events/0)

    with {:ok, tm_events} <- fetch_ticketmaster_events_fun.() do
      Logger.info("[venue_parser] ticketmaster events fetched count=#{length(tm_events)}")

      {:ok,
       Jason.encode!(%{
         "source" => "salt_shed_ticketmaster_api",
         "fetched_at" => DateTime.utc_now(:second) |> DateTime.to_iso8601(),
         "events" => tm_events
       })}
    else
      {:error, reason} ->
        Logger.warning("[venue_parser] ticketmaster fetch failed reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => "salt_shed_ticketmaster_api", "events" => events}}
      when is_list(events) ->
        events
        |> Enum.map(&ticketmaster_event_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)

      _ ->
        HtmlLdJson.extract_events(payload)
    end
  end

  defp fetch_salt_shed_ticketmaster_events do
    events =
      @salt_shed_tm_urls
      |> Enum.flat_map(fn url ->
        case Req.get(url: url) do
          {:ok, %Req.Response{status: status, body: body}}
          when status in 200..299 and is_map(body) ->
            get_in(body, ["_embedded", "events"]) || []

          {:ok, %Req.Response{status: status}} ->
            Logger.warning("[venue_parser] ticketmaster non-200 status=#{status} url=#{url}")
            []

          {:error, reason} ->
            Logger.warning(
              "[venue_parser] ticketmaster request failed reason=#{inspect(reason)} url=#{url}"
            )

            []
        end
      end)

    {:ok, events}
  rescue
    error -> {:error, error}
  end

  defp ticketmaster_event_to_event(event) when is_map(event) do
    name = event["name"]
    url = event["url"]

    start_date =
      get_in(event, ["dates", "start", "dateTime"]) ||
        get_in(event, ["dates", "start", "localDate"])

    if is_binary(name) and is_binary(start_date) do
      %{name: name, start_date: start_date, url: url}
    end
  end

  defp ticketmaster_event_to_event(_), do: nil
end
