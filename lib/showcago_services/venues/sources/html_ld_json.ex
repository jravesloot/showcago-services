defmodule ShowcagoServices.Venues.Sources.HtmlLdJson do
  @moduledoc false

  @behaviour ShowcagoServices.Venues.Source

  @default_refresh_interval_seconds 3_600

  @impl true
  def source_key, do: "html_ld_json"

  @impl true
  def venue_name, do: "html_ld_json"

  @impl true
  def default_refresh_interval_seconds, do: @default_refresh_interval_seconds

  @impl true
  def collect_payload(venue, opts) do
    fetch_html_fun = Keyword.get(opts, :fetch_html_fun, &fetch_html_from_url/1)

    cond do
      is_nil(venue.website) or String.trim(venue.website) == "" ->
        {:error, :missing_website}

      true ->
        fetch_html_fun.(venue.website)
    end
  end

  @impl true
  def extract_events(payload) when is_binary(payload) do
    ~r/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/ims
    |> Regex.scan(payload, capture: :all_but_first)
    |> Enum.map(&List.first/1)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(&decode_ld_json_events/1)
    |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)
  end

  defp fetch_html_from_url(url) do
    case Req.get(url: url) do
      {:ok, %Req.Response{status: status, body: body}}
      when status in 200..299 and is_binary(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_ld_json_events(json_blob) do
    case Jason.decode(json_blob) do
      {:ok, decoded} -> collect_event_objects(decoded)
      _ -> []
    end
  end

  defp collect_event_objects(%{"@graph" => graph}) when is_list(graph) do
    Enum.flat_map(graph, &collect_event_objects/1)
  end

  defp collect_event_objects(%{"@type" => type} = object) when is_binary(type) do
    if String.contains?(String.downcase(type), "event") do
      build_event_from_object(object)
    else
      Enum.flat_map(object, fn {_k, v} -> collect_event_objects(v) end)
    end
  end

  defp collect_event_objects(%{"@type" => types} = object) when is_list(types) do
    if Enum.any?(types, &(is_binary(&1) and String.contains?(String.downcase(&1), "event"))) do
      build_event_from_object(object)
    else
      Enum.flat_map(object, fn {_k, v} -> collect_event_objects(v) end)
    end
  end

  defp collect_event_objects(map) when is_map(map) do
    Enum.flat_map(map, fn {_k, v} -> collect_event_objects(v) end)
  end

  defp collect_event_objects(list) when is_list(list) do
    Enum.flat_map(list, &collect_event_objects/1)
  end

  defp collect_event_objects(_), do: []

  defp build_event_from_object(object) do
    name = object["name"]
    start_date = object["startDate"]

    if is_binary(name) and is_binary(start_date) do
      [%{name: name, start_date: start_date, url: object["url"]}]
    else
      []
    end
  end
end
