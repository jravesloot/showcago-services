defmodule ShowcagoServices.Venues.Sources.ChopShopDice do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @dice_api_url "https://partners-endpoint.dice.fm/api/v2/events"
  @dice_api_key "gc1iKklO05HOTvSuQyoH7dhPJTrWIWO3Dlhwkqc6"
  @venue_name "Chop Shop"

  @impl true
  def source_key, do: "chop_shop_dice"

  @impl true
  def venue_name, do: @venue_name

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_dice_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] chop shop dice events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => "chop_shop_dice_api",
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] chop shop dice fetch failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => "chop_shop_dice_api", "events" => events}}
      when is_list(events) ->
        events
        |> Enum.map(&dice_event_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)

      _ ->
        []
    end
  end

  defp fetch_dice_events do
    url =
      @dice_api_url <>
        "?" <>
        URI.encode_query(
          [
            {"page[size]", "200"},
            {"types", "linkout,event"},
            {"filter[venues][]", @venue_name}
          ],
          :rfc3986
        )

    case Req.get(url: url, headers: [{"x-api-key", @dice_api_key}]) do
      {:ok, %Req.Response{status: status, body: %{"data" => events}}}
      when status in 200..299 and is_list(events) ->
        {:ok, events}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] chop shop dice non-200 status=#{status}")

        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] chop shop dice request failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp dice_event_to_event(%{"name" => name, "date" => date} = event) when is_binary(name) and is_binary(date) do
    url =
      case event["perm_name"] do
        perm_name when is_binary(perm_name) -> "https://dice.fm/event/#{perm_name}"
        _ -> event["url"]
      end

    %{name: name, start_date: date, url: url}
  end

  defp dice_event_to_event(_), do: nil
end
