defmodule ShowcagoServices.Venues.Sources.VicTheatreWebsite do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @vic_url "https://www.jamusa.com/venues/the-vic"
  @payload_source "vic_theatre_website"

  @month_map %{
    "jan" => 1,
    "january" => 1,
    "feb" => 2,
    "february" => 2,
    "mar" => 3,
    "march" => 3,
    "apr" => 4,
    "april" => 4,
    "may" => 5,
    "jun" => 6,
    "june" => 6,
    "jul" => 7,
    "july" => 7,
    "aug" => 8,
    "august" => 8,
    "sep" => 9,
    "sept" => 9,
    "september" => 9,
    "oct" => 10,
    "october" => 10,
    "nov" => 11,
    "november" => 11,
    "dec" => 12,
    "december" => 12
  }

  @impl true
  def source_key, do: @payload_source

  @impl true
  def venue_name, do: "The Vic Theatre"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_vic_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] vic theatre website events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => @payload_source,
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] vic theatre website fetch failed reason=#{inspect(reason)}")

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

  defp fetch_vic_events do
    case Req.get(url: @vic_url, headers: [{"user-agent", "ShowcagoServices/1.0"}]) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, parse_events_from_html(body)}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] vic theatre website non-200 status=#{status}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] vic theatre website request failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  def parse_events_from_html(html) when is_binary(html) do
    html
    |> String.split(~r/<div class="eventItem\b/)
    |> Enum.drop(1)
    |> Enum.map(&parse_event_block/1)
    |> Enum.reject(&is_nil/1)
  rescue
    error ->
      Logger.warning("[venue_parser] vic theatre website parse failed reason=#{inspect(error)}")
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
    case Regex.run(~r/<h3 class="title[^"]*">\s*<a[^>]*>([^<]+)<\/a>/s, block) do
      [_, title] -> {:ok, title |> String.trim() |> decode_html_entities()}
      _ -> :error
    end
  end

  defp extract_event_url(block) do
    case Regex.run(~r/<h3 class="title[^"]*">\s*<a href="([^"]+)"/, block) do
      [_, url] -> {:ok, url}
      _ -> {:ok, nil}
    end
  end

  defp extract_event_date(block) do
    case Regex.run(~r/aria-label="([^"]+)"/, block) do
      [_, date_label] -> parse_date_label(date_label)
      _ -> :error
    end
  end

  @doc false
  def parse_date_label(date_text) when is_binary(date_text) do
    case Regex.run(~r/^\s*([A-Za-z]+)\s+(\d{1,2})\s+(\d{4})\s*$/, String.trim(date_text)) do
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
    |> String.replace("&rsquo;", "\u2019")
    |> String.replace("&lsquo;", "\u2018")
    |> String.replace("&ndash;", "\u2013")
    |> String.replace("&mdash;", "\u2014")
    |> String.replace("&#038;", "&")
  end
end
