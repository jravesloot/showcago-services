defmodule ShowcagoServices.Venues.Sources.RadiusWebsite do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @radius_url "https://www.radius-chicago.com/events"
  @payload_source "radius_website"

  @month_map %{
    "jan" => 1,
    "feb" => 2,
    "mar" => 3,
    "apr" => 4,
    "may" => 5,
    "jun" => 6,
    "jul" => 7,
    "aug" => 8,
    "sep" => 9,
    "oct" => 10,
    "nov" => 11,
    "dec" => 12
  }

  @impl true
  def source_key, do: @payload_source

  @impl true
  def venue_name, do: "Radius Chicago"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_radius_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] radius website events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => @payload_source,
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] radius website fetch failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => @payload_source, "events" => events}} when is_list(events) ->
        events
        |> Enum.map(&event_map_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> event.url || {event.name, event.start_date} end)

      _ ->
        []
    end
  end

  defp event_map_to_event(%{"name" => name, "start_date" => start_date} = event)
       when is_binary(name) and is_binary(start_date) do
    %{name: name, start_date: start_date, url: event["url"]}
  end

  defp event_map_to_event(_), do: nil

  defp fetch_radius_events do
    case Req.get(url: @radius_url, headers: [{"user-agent", "ShowcagoServices/1.0"}]) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, parse_events_from_html(body)}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] radius website non-200 status=#{status}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] radius website request failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  def parse_events_from_html(html) when is_binary(html) do
    html
    |> String.split(~r/<div class="entry\b/)
    |> Enum.drop(1)
    |> Enum.map(&parse_event_block/1)
    |> Enum.reject(&is_nil/1)
  rescue
    error ->
      Logger.warning("[venue_parser] radius website parse failed reason=#{inspect(error)}")
      []
  end

  defp parse_event_block(block) do
    with {:ok, name} <- extract_event_title(block),
         {:ok, url} <- extract_event_url(block),
         {:ok, iso_date} <- extract_event_date(block) do
      %{"name" => name, "start_date" => iso_date, "url" => url}
    else
      _ -> nil
    end
  end

  defp extract_event_title(block) do
    case Regex.run(
           ~r/<h3 class="carousel_item_title_small">\s*<a[^>]*>\s*(.+?)\s*<\/a>/s,
           block
         ) do
      [_, title] -> {:ok, title |> String.trim() |> decode_html_entities()}
      _ -> :error
    end
  end

  defp extract_event_url(block) do
    case Regex.run(
           ~r/<h3 class="carousel_item_title_small">\s*<a href="([^"]+)"/,
           block
         ) do
      [_, url] -> {:ok, url}
      _ -> {:ok, nil}
    end
  end

  defp extract_event_date(block) do
    # Date is in <span class="date">... Fri, Mar 27, 2026 ...</span>
    case Regex.run(~r/<span class="date">.*?<\/span>\s*(\w+,\s+\w+\s+\d{1,2},\s+\d{4})/s, block) do
      [_, date_text] -> parse_date_text(date_text)
      _ -> :error
    end
  end

  @doc false
  def parse_date_text(date_text) when is_binary(date_text) do
    # Handles "Day, Mon DD, YYYY" format (e.g., "Fri, Mar 27, 2026")
    case Regex.run(~r/\w+,\s+(\w+)\s+(\d{1,2}),\s+(\d{4})/, String.trim(date_text)) do
      [_, month_str, day_str, year_str] ->
        month_key = String.downcase(month_str)

        with month when is_integer(month) <- Map.get(@month_map, month_key),
             day = String.to_integer(day_str),
             year = String.to_integer(year_str),
             {:ok, date} <- Date.new(year, month, day) do
          {:ok, Date.to_iso8601(date)}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp decode_html_entities(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#039;", "'")
    |> String.replace("&#038;", "&")
  end
end
