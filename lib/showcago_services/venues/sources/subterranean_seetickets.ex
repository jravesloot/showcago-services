defmodule ShowcagoServices.Venues.Sources.SubterraneanSeeTickets do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @subterranean_url "https://subt.net"

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
  def source_key, do: "subterranean_seetickets"

  @impl true
  def venue_name, do: "Subterranean"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_subterranean_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] subterranean seetickets events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => "subterranean_seetickets",
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] subterranean seetickets fetch failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => "subterranean_seetickets", "events" => events}}
      when is_list(events) ->
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

  defp fetch_subterranean_events do
    case Req.get(url: @subterranean_url, headers: [{"user-agent", "ShowcagoServices/1.0"}]) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        events = parse_events_from_html(body)
        {:ok, events}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] subterranean seetickets non-200 status=#{status}")

        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] subterranean seetickets request failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  def parse_events_from_html(html) when is_binary(html) do
    html
    |> String.split("seetickets-list-event-container")
    |> Enum.drop(1)
    |> Enum.map(&parse_event_block/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_event_block(block) do
    with {:ok, name} <- extract_event_title(block),
         {:ok, url} <- extract_event_url(block),
         {:ok, date_text} <- extract_event_date(block),
         {:ok, iso_date} <- parse_date_text(date_text) do
      %{"name" => name, "start_date" => iso_date, "url" => url}
    else
      _ -> nil
    end
  end

  defp extract_event_title(block) do
    case Regex.run(~r/event-title"[^>]*>.*?<a[^>]*>([^<]+)<\/a>/s, block) do
      [_, title] -> {:ok, String.trim(title)}
      _ -> :error
    end
  end

  defp extract_event_url(block) do
    case Regex.run(~r/event-title"[^>]*>.*?<a\s+href="([^"]+)"/s, block) do
      [_, url] -> {:ok, url}
      _ -> {:ok, nil}
    end
  end

  defp extract_event_date(block) do
    case Regex.run(~r/event-date">([^<]+)</, block) do
      [_, date_text] -> {:ok, String.trim(date_text)}
      _ -> :error
    end
  end

  @doc false
  def parse_date_text(date_text) do
    case Regex.run(~r/\w+\s+(\w+)\s+(\d+)/, date_text) do
      [_, month_str, day_str] ->
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
        case Regex.run(~r/(\w+)\s+(\d+)\s*-/, date_text) do
          [_, month_str, day_str] ->
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
