defmodule ShowcagoServices.Venues.Sources.SchubasTavernLhSt do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  require Logger

  @default_refresh_interval_seconds 3_600
  @api_base_url "https://lh-st.com/wp-json/wp/v2/shows"
  @venue_post_title "Schubas"
  @pages_to_fetch 2

  @impl true
  def source_key, do: "schubas_tavern_lh_st"

  @impl true
  def venue_name, do: "Schubas Tavern"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(_venue, opts) do
    fetch_events_fun =
      Keyword.get(opts, :fetch_events_fun, &fetch_schubas_events/0)

    case fetch_events_fun.() do
      {:ok, events} ->
        Logger.info("[venue_parser] schubas tavern lh-st events fetched count=#{length(events)}")

        {:ok,
         Jason.encode!(%{
           "source" => "schubas_tavern_lh_st_api",
           "fetched_at" => :second |> DateTime.utc_now() |> DateTime.to_iso8601(),
           "events" => events
         })}

      {:error, reason} ->
        Logger.warning("[venue_parser] schubas tavern lh-st fetch failed reason=#{inspect(reason)}")

        {:error, reason}
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => "schubas_tavern_lh_st_api", "events" => events}}
      when is_list(events) ->
        events
        |> Enum.map(&wp_show_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)

      _ ->
        []
    end
  end

  defp fetch_schubas_events do
    events =
      1..@pages_to_fetch
      |> Enum.flat_map(&fetch_page/1)
      |> Enum.filter(&schubas_show?/1)

    {:ok, events}
  rescue
    error -> {:error, error}
  end

  defp fetch_page(page) do
    url = "#{@api_base_url}?per_page=100&page=#{page}"

    case Req.get(url: url, headers: [{"user-agent", "ShowcagoServices/1.0"}]) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_list(body) ->
        body

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("[venue_parser] schubas tavern lh-st non-200 status=#{status} page=#{page}")

        []

      {:error, reason} ->
        Logger.warning("[venue_parser] schubas tavern lh-st request failed reason=#{inspect(reason)} page=#{page}")

        []
    end
  end

  defp schubas_show?(show) when is_map(show) do
    get_in(show, ["acf", "venue", "post_title"]) == @venue_post_title
  end

  defp schubas_show?(_), do: false

  defp wp_show_to_event(%{"acf" => acf, "link" => link} = _show) when is_map(acf) and is_binary(link) do
    headliner = get_headliner_name(acf)
    date_str = acf["date_and_time_of_show"]

    with name when is_binary(name) <- headliner,
         start_date when is_binary(start_date) <- parse_show_date(date_str) do
      %{name: name, start_date: start_date, url: link}
    else
      _ -> nil
    end
  end

  defp wp_show_to_event(_), do: nil

  defp get_headliner_name(%{"headliner" => [%{"post_title" => name} | _]}) when is_binary(name), do: name

  defp get_headliner_name(_), do: nil

  defp parse_show_date(date_str) when is_binary(date_str) do
    case Regex.run(~r/^(\d{2})\/(\d{2})\/(\d{4})\s+(\d{1,2}):(\d{2})\s+(am|pm)$/i, date_str) do
      [_, month, day, year, hour, minute, ampm] ->
        hour = String.to_integer(hour)
        minute = String.to_integer(minute)

        hour =
          cond do
            String.downcase(ampm) == "am" and hour == 12 -> 0
            String.downcase(ampm) == "pm" and hour != 12 -> hour + 12
            true -> hour
          end

        "#{year}-#{month}-#{day}T#{pad(hour)}:#{pad(minute)}:00"

      _ ->
        nil
    end
  end

  defp parse_show_date(_), do: nil

  defp pad(n) when n < 10, do: "0#{n}"
  defp pad(n), do: "#{n}"
end
