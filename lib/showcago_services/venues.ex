defmodule ShowcagoServices.Venues do
  @moduledoc """
  Venue domain queries and business logic.
  """

  import Ecto.Query, warn: false
  require Logger

  alias ShowcagoServices.Artists
  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.Venue

  @default_schedule_refresh_interval_seconds 3_600
  @salt_shed_tm_urls [
    "https://app.ticketmaster.com/discovery/v2/events.json?size=200&apikey=VlcOb6C2Y4W0iGius6pFX1Gh7a9GnKyg&venueId=KovZ917AI5F",
    "https://app.ticketmaster.com/discovery/v2/events.json?size=200&apikey=VlcOb6C2Y4W0iGius6pFX1Gh7a9GnKyg&venueId=KovZ917Amf0"
  ]

  @spec list_venues(keyword()) :: [Venue.t()]
  def list_venues(opts \\ []) do
    search = Keyword.get(opts, :search)
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset)

    Venue
    |> maybe_search_venues(search)
    |> order_by([v], asc: v.name)
    |> maybe_limit(limit)
    |> maybe_offset(offset)
    |> Repo.all()
  end

  @spec count_venues(keyword()) :: non_neg_integer()
  def count_venues(opts \\ []) do
    search = Keyword.get(opts, :search)

    Venue
    |> maybe_search_venues(search)
    |> exclude(:order_by)
    |> Repo.aggregate(:count, :id)
  end

  defp maybe_search_venues(query, nil), do: query
  defp maybe_search_venues(query, ""), do: query

  defp maybe_search_venues(query, search) do
    search_term = "%#{search}%"

    from(v in query,
      where:
        ilike(v.name, ^search_term) or
          ilike(v.city, ^search_term) or
          ilike(v.address, ^search_term)
    )
  end

  defp maybe_limit(query, nil), do: query

  defp maybe_limit(query, limit) when is_integer(limit) and limit > 0 do
    from(q in query, limit: ^limit)
  end

  defp maybe_limit(query, _invalid_limit), do: query

  defp maybe_offset(query, nil), do: query

  defp maybe_offset(query, offset) when is_integer(offset) and offset >= 0 do
    from(q in query, offset: ^offset)
  end

  defp maybe_offset(query, _invalid_offset), do: query

  @spec get_venue!(term()) :: Venue.t()
  def get_venue!(id), do: Repo.get!(Venue, id)

  @spec create_venue(map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def create_venue(attrs \\ %{}) do
    %Venue{}
    |> Venue.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_venue(Venue.t(), map()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def update_venue(%Venue{} = venue, attrs) do
    venue
    |> Venue.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_venue(Venue.t()) :: {:ok, Venue.t()} | {:error, Ecto.Changeset.t()}
  def delete_venue(%Venue{} = venue) do
    Repo.delete(venue)
  end

  @spec venue_changeset(Venue.t(), map()) :: Ecto.Changeset.t()
  def venue_changeset(%Venue{} = venue, attrs \\ %{}) do
    Venue.changeset(venue, attrs)
  end

  @doc """
  Fetches and stores raw schedule HTML from a venue website.

  By default this throttles requests and skips fetches when data was recently collected.
  Set `force: true` to bypass throttling.
  """
  @spec collect_schedule_html(Venue.t(), keyword()) ::
          {:ok, Venue.t(), :updated | :skipped} | {:error, term()}
  def collect_schedule_html(%Venue{} = venue, opts \\ []) do
    force? = Keyword.get(opts, :force, false)

    refresh_interval_seconds =
      Keyword.get(opts, :refresh_interval_seconds, @default_schedule_refresh_interval_seconds)

    fetch_html_fun = Keyword.get(opts, :fetch_html_fun, &fetch_html_from_url/1)

    cond do
      is_nil(venue.website) or String.trim(venue.website) == "" ->
        {:error, :missing_website}

      force? or stale_for_collection?(venue.data_last_collected, refresh_interval_seconds) ->
        do_collect_schedule_html(venue, fetch_html_fun)

      true ->
        {:ok, venue, :skipped}
    end
  end

  @doc """
  Collects schedule data for The Salt Shed via API and stores raw payload.

  This path does not scrape website HTML. It uses the same Ticketmaster
  endpoints as the Salt Shed event widget and stores the raw API payload in
  `schedule_html` for later parsing.
  """
  @spec collect_salt_shed_schedule_data(keyword()) ::
          {:ok, Venue.t(), :updated | :skipped} | {:error, term()}
  def collect_salt_shed_schedule_data(opts \\ []) do
    case Repo.get_by(Venue, name: "The Salt Shed") do
      nil ->
        {:error, :salt_shed_not_found}

      venue ->
        force? = Keyword.get(opts, :force, false)

        refresh_interval_seconds =
          Keyword.get(opts, :refresh_interval_seconds, @default_schedule_refresh_interval_seconds)

        fetch_ticketmaster_events_fun =
          Keyword.get(
            opts,
            :fetch_ticketmaster_events_fun,
            &fetch_salt_shed_ticketmaster_events/0
          )

        cond do
          force? or stale_for_collection?(venue.data_last_collected, refresh_interval_seconds) ->
            do_collect_salt_shed_schedule_data(venue, fetch_ticketmaster_events_fun)

          true ->
            {:ok, venue, :skipped}
        end
    end
  end

  defp do_collect_schedule_html(venue, fetch_html_fun) do
    with {:ok, html} <- fetch_html_fun.(venue.website),
         {:ok, updated_venue} <- update_venue(venue, %{schedule_html: html}) do
      {:ok, updated_venue, :updated}
    end
  end

  defp stale_for_collection?(nil, _refresh_interval_seconds), do: true

  defp stale_for_collection?(%DateTime{} = last_collected_at, refresh_interval_seconds) do
    DateTime.diff(DateTime.utc_now(:second), last_collected_at, :second) >=
      refresh_interval_seconds
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

  defp do_collect_salt_shed_schedule_data(venue, fetch_ticketmaster_events_fun) do
    with {:ok, tm_events} <- fetch_ticketmaster_events_fun.() do
      Logger.info("[venue_parser] ticketmaster events fetched count=#{length(tm_events)}")

      payload =
        Jason.encode!(%{
          "source" => "salt_shed_ticketmaster_api",
          "fetched_at" => DateTime.utc_now(:second) |> DateTime.to_iso8601(),
          "events" => tm_events
        })

      update_venue(venue, %{schedule_html: payload})
      |> case do
        {:ok, updated_venue} -> {:ok, updated_venue, :updated}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.warning("[venue_parser] ticketmaster fetch failed reason=#{inspect(reason)}")
        {:error, reason}
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

  @doc """
  Parses The Salt Shed `schedule_html` and creates matched shows.

  This uses stored schedule payload only and does not fetch from the website/API.
  """
  @spec parse_salt_shed_schedule_html_and_create_shows() :: {:ok, map()} | {:error, atom()}
  def parse_salt_shed_schedule_html_and_create_shows do
    case Repo.get_by(Venue, name: "The Salt Shed") do
      nil -> {:error, :salt_shed_not_found}
      venue -> parse_schedule_html_and_create_shows(venue)
    end
  end

  @doc """
  Parses a venue's `schedule_html`, matches artists, and creates shows.
  """
  @spec parse_schedule_html_and_create_shows(Venue.t()) :: {:ok, map()} | {:error, atom()}
  def parse_schedule_html_and_create_shows(%Venue{} = venue) do
    if is_nil(venue.schedule_html) or String.trim(venue.schedule_html) == "" do
      {:error, :missing_schedule_html}
    else
      events = extract_events_from_schedule_payload(venue.schedule_html)

      result =
        Enum.reduce(events, %{matched: 0, created: 0, skipped: 0}, fn event, acc ->
          Logger.info("[venue_parser] found event title=\"#{event.name}\" venue_id=#{venue.id}")

          case Artists.match_artists_in_text(event.name, limit: 1) do
            [%{artist: artist} | _] ->
              case find_or_create_show(venue, artist.id, event) do
                :created -> %{acc | matched: acc.matched + 1, created: acc.created + 1}
                :existing -> %{acc | matched: acc.matched + 1, skipped: acc.skipped + 1}
                :invalid_event -> %{acc | skipped: acc.skipped + 1}
              end

            _ ->
              %{acc | skipped: acc.skipped + 1}
          end
        end)

      {:ok,
       %{
         parsed_events_count: length(events),
         matched_events_count: result.matched,
         created_shows_count: result.created,
         skipped_events_count: result.skipped
       }}
    end
  end

  defp extract_events_from_schedule_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"source" => "salt_shed_ticketmaster_api", "events" => events}}
      when is_list(events) ->
        events
        |> Enum.map(&ticketmaster_event_to_event/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)

      _ ->
        extract_events_from_html(payload)
    end
  end

  defp find_or_create_show(venue, artist_id, event) do
    with {:ok, starts_at} <- parse_event_datetime(event.start_date) do
      existing_show_id =
        from(s in Show,
          join: sa in "show_artists",
          on: sa.show_id == s.id,
          where: s.venue_id == ^venue.id and s.date == ^starts_at and sa.artist_id == ^artist_id,
          select: s.id,
          limit: 1
        )
        |> Repo.one()

      if existing_show_id do
        :existing
      else
        now = DateTime.utc_now(:second)

        Repo.transaction(fn ->
          {:ok, show} =
            %Show{}
            |> Show.changeset(%{
              date: starts_at,
              venue_id: venue.id,
              ticket_url: event.url,
              notes: event.name
            })
            |> Repo.insert()

          Repo.insert_all("show_artists", [
            %{show_id: show.id, artist_id: artist_id, inserted_at: now, updated_at: now}
          ])
        end)

        :created
      end
    else
      _ -> :invalid_event
    end
  end

  defp extract_events_from_html(html) do
    ~r/<script[^>]*type=["']application\/ld\+json["'][^>]*>(.*?)<\/script>/ims
    |> Regex.scan(html, capture: :all_but_first)
    |> Enum.map(&List.first/1)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(&decode_ld_json_events/1)
    |> Enum.uniq_by(fn event -> {event.name, event.start_date} end)
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

  defp parse_event_datetime(start_date) when is_binary(start_date) do
    case DateTime.from_iso8601(start_date) do
      {:ok, dt, _offset} ->
        {:ok, DateTime.truncate(dt, :second)}

      _ ->
        with {:ok, naive} <- NaiveDateTime.from_iso8601(start_date) do
          {:ok, DateTime.from_naive!(NaiveDateTime.truncate(naive, :second), "Etc/UTC")}
        else
          _ ->
            with {:ok, date} <- Date.from_iso8601(start_date),
                 {:ok, naive} <- NaiveDateTime.new(date, ~T[00:00:00]),
                 {:ok, dt} <- DateTime.from_naive(naive, "Etc/UTC") do
              {:ok, dt}
            else
              _ -> {:error, :invalid_start_date}
            end
        end
    end
  end

  defp parse_event_datetime(_), do: {:error, :invalid_start_date}
end
