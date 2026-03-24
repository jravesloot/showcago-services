defmodule ShowcagoServices.Venues.Sources.MetroWebsite do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @metro_url "https://metrochicago.com/events/"
  @payload_source "metro_website_html"

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
  def source_key, do: "metro_website"

  @impl true
  def venue_name, do: "Metro"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get_lazy(opts, :fetch_events_fun, fn ->
        Keyword.get(opts, :fetch_ticketmaster_events_fun, &fetch_metro_events/0)
      end)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] metro website events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => @payload_source,
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] metro website fetch failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => source, "events" => events}}
      when source in [@payload_source, "metro_ticketmaster_api"] and is_list(events) ->
        events
        |> Enum.map(&event_map_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> event.url || {event.name, event.start_date} end)

      _ ->
        []
    end
  end

  @doc false
  def parse_events_from_html(html) when is_binary(html) do
    html
    |> extract_upcoming_events()
    |> Kernel.++(extract_just_announced_events(html))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1["url"])
  rescue
    error ->
      Logger.warning("[venue_parser] metro website parse failed reason=#{inspect(error)}")
      []
  end

  @doc false
  def parse_date_label(date_text) when is_binary(date_text) do
    case Regex.run(~r/^[A-Za-z]{3},\s+([A-Za-z]{3,9})\s+(\d{1,2})$/, String.trim(date_text)) do
      [_, month_text, day_text] ->
        month_key = String.downcase(month_text)

        with month when is_integer(month) <- Map.get(@month_map, month_key),
             day = String.to_integer(day_text),
             year = infer_year(month, day),
             {:ok, date} <- Date.new(year, month, day) do
          {:ok, Date.to_iso8601(date)}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp fetch_metro_events do
    case Req.get(url: @metro_url, headers: [{"user-agent", "ShowcagoServices/1.0"}]) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, parse_events_from_html(body)}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] metro website non-200 status=#{status}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] metro website request failed reason=#{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp extract_upcoming_events(html) do
    ~r/<div class\s*=\s*"col-12 eventWrapper rhpSingleEvent[^\"]*".*?<div id="eventDate"[^>]*>\s*([^<]+?)\s*<\/div>.*?<a id\s*=\s*"eventTitle" class="url" href="([^"]*\/metro-chicago\/chicago-illinois\/)" title="([^"]+)"[^>]*>/s
    |> Regex.scan(
      html,
      capture: :all_but_first
    )
    |> Enum.map(fn [date_text, url, title] -> build_event_map(title, date_text, url) end)
  end

  defp extract_just_announced_events(html) do
    ~r/<div class="col-12 p-0 rhp-events-list-widget-events">.*?<div class\s*=\s*"mb-2 eventDate eventMonth text-uppercase font0by875"\s*>\s*([^<]+?)\s*<\/div>.*?<h4 class="entry-title summary mb-0">\s*<a href="([^"]*\/metro-chicago\/chicago-illinois\/)"[^>]*>\s*([^<]+?)\s*<\/a>/s
    |> Regex.scan(
      html,
      capture: :all_but_first
    )
    |> Enum.map(fn [date_text, url, title] -> build_event_map(title, date_text, url) end)
  end

  defp build_event_map(title, date_text, url) do
    case parse_date_label(date_text) do
      {:ok, start_date} ->
        %{
          "name" => normalize_text(title),
          "start_date" => start_date,
          "url" => url
        }

      _ ->
        nil
    end
  end

  defp event_map_to_event(%{"name" => name, "start_date" => start_date} = event)
       when is_binary(name) and is_binary(start_date) do
    %{name: normalize_text(name), start_date: start_date, url: event["url"]}
  end

  defp event_map_to_event(event) when is_map(event) do
    name = event["name"]
    url = event["url"]

    start_date =
      get_in(event, ["dates", "start", "dateTime"]) ||
        get_in(event, ["dates", "start", "localDate"])

    if is_binary(name) and is_binary(start_date) do
      %{name: normalize_text(name), start_date: start_date, url: url}
    end
  end

  defp event_map_to_event(_), do: nil

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

  defp normalize_text(text) do
    text
    |> String.trim()
    |> String.replace("&#038;", "&")
    |> String.replace("&amp;#038;", "&")
    |> String.replace("&amp;", "&")
    |> String.replace("&#8217;", "'")
    |> String.replace("&#8230;", "…")
    |> String.replace("&#8211;", "–")
    |> String.replace("&nbsp;", " ")
    |> String.replace(~r/[\x{200B}\x{200C}\x{200D}\x{FEFF}]/u, "")
    |> String.replace(~r/\s+/, " ")
  end
end
