defmodule ShowcagoServices.Venues.Sources.ReggiesWebsite do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @base_url "https://www.reggieslive.com"
  @pages ["#{@base_url}/", "#{@base_url}/page/2/"]
  @payload_source "reggies_website"

  @impl true
  def source_key, do: @payload_source

  @impl true
  def venue_name, do: "Reggie's"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_reggies_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] reggies website events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => @payload_source,
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] reggies website fetch failed reason=#{inspect(reason)}")
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

  defp fetch_reggies_events do
    Enum.reduce_while(@pages, {:ok, []}, fn page_url, {:ok, acc} ->
      case fetch_page(page_url) do
        {:ok, events} -> {:cont, {:ok, acc ++ events}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp fetch_page(url) do
    case Req.get(
           url: url,
           headers: [
             {"user-agent",
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"}
           ]
         ) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, parse_events_from_html(body)}

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] reggies website non-200 status=#{status} url=#{url}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("[venue_parser] reggies website request failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  @doc false
  def parse_events_from_html(html) when is_binary(html) do
    html
    |> String.split(~r/<article id="show-/)
    |> Enum.drop(1)
    |> Enum.map(&parse_event_block/1)
    |> Enum.reject(&is_nil/1)
  rescue
    error ->
      Logger.warning("[venue_parser] reggies website parse failed reason=#{inspect(error)}")
      []
  end

  defp parse_event_block(block) do
    with {:ok, name} <- extract_event_title(block),
         {:ok, iso_date} <- extract_event_date(block) do
      url = extract_event_url(block)
      %{"name" => name, "start_date" => iso_date, "url" => url}
    else
      _ -> nil
    end
  end

  defp extract_event_title(block) do
    case Regex.run(~r/<h2 class="show-title band-title">([^<]+)<\/h2>/, block) do
      [_, title] -> {:ok, title |> String.trim() |> decode_html_entities()}
      _ -> :error
    end
  end

  defp extract_event_date(block) do
    case Regex.run(~r/<time datetime="(\d{4}-\d{2}-\d{2})"/, block) do
      [_, date_str] ->
        case Date.from_iso8601(date_str) do
          {:ok, date} -> {:ok, Date.to_iso8601(date)}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp extract_event_url(block) do
    case Regex.run(~r/<a href="([^"]+)" class="expandshow"/, block) do
      [_, url] -> url
      _ -> nil
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
