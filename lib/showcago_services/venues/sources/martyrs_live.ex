defmodule ShowcagoServices.Venues.Sources.MartyrsLive do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @calendar_url "https://martyrslive.com/calendar"

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
    "september" => 9,
    "oct" => 10,
    "october" => 10,
    "nov" => 11,
    "november" => 11,
    "dec" => 12,
    "december" => 12
  }

  @impl true
  def source_key, do: "martyrs_live"

  @impl true
  def venue_name, do: "Martyrs'"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_calendar_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] martyrs live events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => "martyrs_live",
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] martyrs live fetch failed reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => "martyrs_live", "events" => events}} when is_list(events) ->
        events
        |> Enum.map(&event_map_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)

      _ ->
        []
    end
  end

  defp event_map_to_event(%{"name" => name, "start_date" => start_date} = event)
       when is_binary(name) and is_binary(start_date) do
    %{name: name, start_date: start_date, url: event["url"]}
  end

  defp event_map_to_event(_), do: nil

  defp fetch_calendar_events do
    case Req.get(url: @calendar_url, headers: [{"user-agent", "ShowcagoServices/1.0"}]) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        events = parse_events_from_html(body)
        {:ok, events}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] martyrs live non-200 status=#{status}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] martyrs live request failed reason=#{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  def parse_events_from_html(html) when is_binary(html) do
    html
    |> String.split(~r/<div class="views-row views-row-\d+/)
    |> Enum.drop(1)
    |> Enum.map(&parse_event_block/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_event_block(block) do
    if String.contains?(block, "status-cancelled") do
      nil
    else
      with {:ok, schedule_text} <- extract_schedule_text(block),
           {:ok, name} <- extract_show_name(block),
           {:ok, iso_date} <- parse_schedule_date(schedule_text) do
        url = extract_show_url(block)
        %{"name" => name, "start_date" => iso_date, "url" => url}
      else
        _ -> nil
      end
    end
  end

  defp extract_schedule_text(block) do
    case Regex.run(~r/field-show-schedule-value">.*?field-content">([^<]+)/s, block) do
      [_, text] -> {:ok, String.trim(text)}
      _ -> :error
    end
  end

  defp extract_show_name(block) do
    case Regex.run(~r/show-bands-nid.*?field-content">.*?<a[^>]*>([^<]+)<\/a>/s, block) do
      [_, name] ->
        name =
          name
          |> String.trim()
          |> decode_html_entities()

        {:ok, name}

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
    |> String.replace("&rdquo;", "\u201D")
    |> String.replace("&ldquo;", "\u201C")
    |> String.replace("&ndash;", "\u2013")
    |> String.replace("&mdash;", "\u2014")
    |> String.replace("&nbsp;", " ")
  end

  defp extract_show_url(block) do
    case Regex.run(~r/edit-submit-(\d+)/, block) do
      [_, nid] -> "https://martyrslive.com/node/#{nid}"
      _ -> nil
    end
  end

  @doc false
  def parse_schedule_date(text) do
    case Regex.run(~r/(\w+),\s+(\w+)\s+(\d+)/, text) do
      [_, _dow, month_str, day_str] ->
        month_lower = String.downcase(month_str)

        case Map.get(@month_map, month_lower) do
          nil ->
            :error

          month ->
            day = String.to_integer(day_str)
            year = infer_year(month, day)

            case Date.new(year, month, day) do
              {:ok, date} -> {:ok, Date.to_iso8601(date)}
              _ -> :error
            end
        end

      _ ->
        :error
    end
  end

  defp infer_year(month, day) do
    today = Date.utc_today()

    case Date.new(today.year, month, day) do
      {:ok, candidate} ->
        if Date.diff(candidate, today) < -60 do
          today.year + 1
        else
          today.year
        end

      _ ->
        today.year
    end
  end
end
