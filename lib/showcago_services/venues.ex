defmodule ShowcagoServices.Venues do
  @moduledoc """
  Venue domain queries and business logic.
  """

  import Ecto.Query, warn: false

  alias ShowcagoServices.Artists
  alias ShowcagoServices.Repo
  alias ShowcagoServices.Schema.Show
  alias ShowcagoServices.Schema.Venue
  alias ShowcagoServices.Schema.VenueSource
  alias ShowcagoServices.Venues.Sources.AragonBallroomTicketmaster
  alias ShowcagoServices.Venues.Sources.BeatKitchenSeeTickets
  alias ShowcagoServices.Venues.Sources.BottomLoungeTicketmaster
  alias ShowcagoServices.Venues.Sources.ChopShopDice
  alias ShowcagoServices.Venues.Sources.ConcordMusicHallTicketmaster
  alias ShowcagoServices.Venues.Sources.EmptyBottleTicketmaster
  alias ShowcagoServices.Venues.Sources.HouseOfBluesTicketmaster
  alias ShowcagoServices.Venues.Sources.LincolnHallLhSt
  alias ShowcagoServices.Venues.Sources.MartyrsLive
  alias ShowcagoServices.Venues.Sources.MetroWebsite
  alias ShowcagoServices.Venues.Sources.ParkWestWebsite
  alias ShowcagoServices.Venues.Sources.RadiusWebsite
  alias ShowcagoServices.Venues.Sources.ReggiesWebsite
  alias ShowcagoServices.Venues.Sources.SaltShedTicketmaster
  alias ShowcagoServices.Venues.Sources.SchubasTavernLhSt
  alias ShowcagoServices.Venues.Sources.ThaliaHallTicketmaster

  require Logger

  @source_modules [
    AragonBallroomTicketmaster,
    BeatKitchenSeeTickets,
    BottomLoungeTicketmaster,
    ChopShopDice,
    ConcordMusicHallTicketmaster,
    EmptyBottleTicketmaster,
    HouseOfBluesTicketmaster,
    LincolnHallLhSt,
    MartyrsLive,
    MetroWebsite,
    ParkWestWebsite,
    RadiusWebsite,
    ReggiesWebsite,
    SaltShedTicketmaster,
    SchubasTavernLhSt,
    ThaliaHallTicketmaster
  ]

  @doc """
  Returns the list of configured source modules.
  """
  def source_modules, do: @source_modules

  @doc """
  Returns true if the given source key has a registered source module.
  """
  @spec known_source_key?(binary()) :: boolean()
  def known_source_key?(source_key) when is_binary(source_key) do
    Enum.any?(@source_modules, &(&1.source_key() == source_key))
  end

  @default_event_artist_match_limit 5

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

  @spec list_shows_for_venue(term(), keyword()) :: [Show.t()]
  def list_shows_for_venue(venue_id, opts \\ []) do
    include_ignored = Keyword.get(opts, :include_ignored, false)

    Show
    |> where([s], s.venue_id == ^venue_id)
    |> maybe_exclude_ignored_shows(include_ignored)
    |> order_by([s], asc: s.date)
    |> preload([:artists])
    |> Repo.all()
  end

  defp maybe_exclude_ignored_shows(query, true), do: query

  defp maybe_exclude_ignored_shows(query, false) do
    where(query, [s], s.ignored == false)
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

  @spec get_venue_by_name(binary()) :: Venue.t() | nil
  def get_venue_by_name(name) when is_binary(name), do: Repo.get_by(Venue, name: name)

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

  @spec list_venue_sources(Venue.t()) :: [VenueSource.t()]
  def list_venue_sources(%Venue{} = venue) do
    Repo.all(
      from(vs in VenueSource,
        where: vs.venue_id == ^venue.id,
        order_by: [asc: vs.source_key, desc: vs.fetched_at, desc: vs.id]
      )
    )
  end

  @spec get_venue_source(Venue.t(), term()) :: VenueSource.t() | nil
  def get_venue_source(%Venue{} = venue, id) do
    Repo.get_by(VenueSource, id: id, venue_id: venue.id)
  end

  @spec change_venue_source(VenueSource.t(), map()) :: Ecto.Changeset.t()
  def change_venue_source(%VenueSource{} = venue_source, attrs \\ %{}) do
    VenueSource.changeset(venue_source, attrs)
  end

  @spec create_venue_source(Venue.t(), map()) ::
          {:ok, VenueSource.t()} | {:error, Ecto.Changeset.t()}
  def create_venue_source(%Venue{} = venue, attrs) when is_map(attrs) do
    attrs = Map.put(attrs, "venue_id", venue.id)

    %VenueSource{}
    |> VenueSource.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_venue_source(VenueSource.t(), map()) ::
          {:ok, VenueSource.t()} | {:error, Ecto.Changeset.t()}
  def update_venue_source(%VenueSource{} = venue_source, attrs) when is_map(attrs) do
    venue_source
    |> VenueSource.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_venue_source(VenueSource.t()) ::
          {:ok, VenueSource.t()} | {:error, Ecto.Changeset.t()}
  def delete_venue_source(%VenueSource{} = venue_source) do
    Repo.delete(venue_source)
  end

  @doc """
  Collects schedule payload for a configured source key.
  """
  @spec collect_schedule_payload_for_source(binary(), keyword()) ::
          {:ok, Venue.t(), :updated | :skipped} | {:error, term()}
  def collect_schedule_payload_for_source(source_key, opts \\ []) when is_binary(source_key) do
    with {:ok, source_module} <- source_module_for_source_key(source_key),
         {:ok, venue} <- venue_for_source_module(source_module) do
      collect_schedule_payload(venue, source_module, opts)
    end
  end

  defp stale_for_collection?(nil, _refresh_interval_seconds), do: true

  defp stale_for_collection?(%DateTime{} = last_collected_at, refresh_interval_seconds) do
    DateTime.diff(DateTime.utc_now(:second), last_collected_at, :second) >=
      refresh_interval_seconds
  end

  @doc """
  Parses and creates shows for a configured source key.
  """
  @spec parse_schedule_payload_and_create_shows_for_source(binary()) ::
          {:ok, map()} | {:error, atom()}
  def parse_schedule_payload_and_create_shows_for_source(source_key) when is_binary(source_key) do
    with {:ok, source_module} <- source_module_for_source_key(source_key),
         {:ok, venue} <- venue_for_source_module(source_module) do
      parse_schedule_payload_and_create_shows(venue, source: source_key)
    end
  end

  @doc """
  Parses a venue's source payload, matches artists, and creates shows.
  """
  @spec parse_schedule_payload_and_create_shows(Venue.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def parse_schedule_payload_and_create_shows(%Venue{} = venue, opts \\ []) do
    source_module = source_module_for_venue(venue, opts)

    if is_nil(source_module) do
      {:error, :source_not_configured}
    else
      payload = get_source_payload(venue, source_module)

      if is_nil(payload) or String.trim(payload) == "" do
        {:error, :missing_schedule_payload}
      else
        events = source_module.extract_events(payload)

        result =
          Enum.reduce(events, %{matched: 0, created: 0, skipped: 0}, fn event, acc ->
            Logger.info("[venue_parser] found event title=\"#{event.name}\" venue_id=#{venue.id}")

            artist_ids =
              event.name
              |> Artists.match_artists_in_text(limit: @default_event_artist_match_limit)
              |> Enum.map(& &1.artist.id)
              |> Enum.uniq()

            case artist_ids do
              [first_artist_id | _] = artist_ids when is_integer(first_artist_id) ->
                case find_or_create_show(venue, artist_ids, event) do
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
  end

  defp source_module_for_venue(%Venue{} = venue) do
    case latest_source_key_for_venue(venue) do
      nil ->
        nil

      source_key ->
        case source_module_for_source_key(source_key) do
          {:ok, source_module} -> source_module
          {:error, :unknown_source} -> nil
        end
    end
  end

  defp source_module_for_venue(%Venue{} = venue, opts) do
    case Keyword.get(opts, :source) do
      source_key when is_binary(source_key) and source_key != "" ->
        case source_module_for_source_key(source_key) do
          {:ok, source_module} -> source_module
          _ -> source_module_for_venue(venue)
        end

      _ ->
        source_module_for_venue(venue)
    end
  end

  defp source_module_for_source_key(source_key) do
    case Enum.find(@source_modules, &(&1.source_key() == source_key)) do
      nil -> {:error, :unknown_source}
      source_module -> {:ok, source_module}
    end
  end

  defp get_venue_for_source(source_module) do
    Repo.one(
      from(vs in VenueSource,
        where: vs.source_key == ^source_module.source_key() and vs.enabled == true,
        order_by: [desc: vs.fetched_at, desc: vs.id],
        join: v in Venue,
        on: v.id == vs.venue_id,
        select: v,
        limit: 1
      )
    )
  end

  defp latest_source_key_for_venue(%Venue{} = venue) do
    Repo.one(
      from(vs in VenueSource,
        where: vs.venue_id == ^venue.id and vs.enabled == true,
        order_by: [desc: vs.fetched_at, desc: vs.id],
        select: vs.source_key,
        limit: 1
      )
    )
  end

  defp venue_for_source_module(source_module) do
    case get_venue_for_source(source_module) do
      nil -> {:error, not_found_error_for_source(source_module.source_key())}
      venue -> {:ok, venue}
    end
  end

  defp not_found_error_for_source(source_key) do
    cond do
      source_key == AragonBallroomTicketmaster.source_key() -> :aragon_ballroom_not_found
      source_key == BeatKitchenSeeTickets.source_key() -> :beat_kitchen_not_found
      source_key == MetroWebsite.source_key() -> :metro_not_found
      source_key == SaltShedTicketmaster.source_key() -> :salt_shed_not_found
      source_key == ThaliaHallTicketmaster.source_key() -> :thalia_hall_not_found
      true -> :venue_not_found_for_source
    end
  end

  defp collect_schedule_payload(venue, source_module, opts) do
    force? = Keyword.get(opts, :force, false)

    refresh_interval_seconds =
      Keyword.get(
        opts,
        :refresh_interval_seconds,
        source_module.default_refresh_interval_seconds()
      )

    if force? or
         stale_for_collection?(
           source_last_collected_at(venue, source_module),
           refresh_interval_seconds
         ) do
      with {:ok, payload} <- source_module.collect_payload(venue, opts),
           {:ok, _source_row} <-
             upsert_source_payload(venue, source_module, payload) do
        {:ok, venue, :updated}
      else
        {:error, reason} = error ->
          record_source_error(venue, source_module, reason)
          error
      end
    else
      {:ok, venue, :skipped}
    end
  end

  defp source_last_collected_at(%Venue{} = venue, source_module) do
    source_fetched_at =
      Repo.one(
        from(vs in VenueSource,
          where: vs.venue_id == ^venue.id and vs.source_key == ^source_module.source_key() and not is_nil(vs.fetched_at),
          order_by: [desc: vs.fetched_at, desc: vs.id],
          select: vs.fetched_at,
          limit: 1
        )
      )

    source_fetched_at
  end

  defp upsert_source_payload(%Venue{} = venue, source_module, payload) when is_binary(payload) do
    attrs = %{
      venue_id: venue.id,
      source_key: source_module.source_key(),
      raw_payload: payload,
      payload_format: infer_payload_format(payload),
      fetched_at: DateTime.utc_now(:second),
      enabled: true,
      last_error: nil,
      updated_at: DateTime.utc_now(:second),
      inserted_at: DateTime.utc_now(:second)
    }

    Repo.insert_all(VenueSource, [attrs],
      on_conflict: [
        set: [
          raw_payload: payload,
          payload_format: infer_payload_format(payload),
          fetched_at: attrs.fetched_at,
          enabled: true,
          last_error: nil,
          updated_at: attrs.updated_at
        ]
      ],
      conflict_target: [:venue_id, :source_key]
    )

    {:ok,
     Repo.get_by!(VenueSource,
       venue_id: venue.id,
       source_key: source_module.source_key()
     )}
  end

  defp record_source_error(%Venue{} = venue, source_module, reason) do
    error_message = inspect(reason, limit: 500)
    Logger.warning("[venues] collection failed source=#{source_module.source_key()} error=#{error_message}")

    Repo.update_all(
      from(vs in VenueSource, where: vs.venue_id == ^venue.id and vs.source_key == ^source_module.source_key()),
      set: [last_error: error_message, updated_at: DateTime.utc_now(:second)]
    )
  end

  defp get_source_payload(%Venue{} = venue, source_module) do
    Repo.one(
      from(vs in VenueSource,
        where: vs.venue_id == ^venue.id and vs.source_key == ^source_module.source_key(),
        order_by: [desc: vs.fetched_at, desc: vs.id],
        select: vs.raw_payload,
        limit: 1
      )
    )
  end

  @spec latest_source_payload_for_venue(Venue.t()) :: binary() | nil
  def latest_source_payload_for_venue(%Venue{} = venue) do
    Repo.one(
      from(vs in VenueSource,
        where: vs.venue_id == ^venue.id,
        order_by: [desc: vs.fetched_at, desc: vs.id],
        select: vs.raw_payload,
        limit: 1
      )
    )
  end

  @spec latest_source_fetched_at_for_venue(Venue.t()) :: DateTime.t() | nil
  def latest_source_fetched_at_for_venue(%Venue{} = venue) do
    Repo.one(
      from(vs in VenueSource,
        where: vs.venue_id == ^venue.id and not is_nil(vs.fetched_at),
        order_by: [desc: vs.fetched_at, desc: vs.id],
        select: vs.fetched_at,
        limit: 1
      )
    )
  end

  defp infer_payload_format(payload) when is_binary(payload) do
    trimmed = String.trim_leading(payload)

    cond do
      String.starts_with?(trimmed, "{") -> "json"
      String.starts_with?(trimmed, "[") -> "json"
      true -> "html"
    end
  end

  defp find_or_create_show(venue, artist_ids, event) when is_list(artist_ids) do
    case parse_event_datetime(event.start_date) do
      {:ok, starts_at} ->
        existing_show_id =
          Repo.one(
            from(s in Show,
              where: s.venue_id == ^venue.id and s.date == ^starts_at and s.notes == ^event.name,
              select: s.id,
              limit: 1
            )
          )

        if existing_show_id do
          attach_artists_to_show(existing_show_id, artist_ids)
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

            insert_show_artists(show.id, artist_ids, now)
          end)

          :created
        end

      _ ->
        :invalid_event
    end
  end

  defp attach_artists_to_show(show_id, artist_ids) do
    insert_show_artists(show_id, artist_ids, DateTime.utc_now(:second))
  end

  defp insert_show_artists(show_id, artist_ids, now) do
    rows =
      Enum.map(artist_ids, fn artist_id ->
        %{show_id: show_id, artist_id: artist_id, inserted_at: now, updated_at: now}
      end)

    Repo.insert_all("show_artists", rows, on_conflict: :nothing)
  end

  defp parse_event_datetime(start_date) when is_binary(start_date) do
    case DateTime.from_iso8601(start_date) do
      {:ok, dt, _offset} ->
        {:ok, DateTime.truncate(dt, :second)}

      _ ->
        case NaiveDateTime.from_iso8601(start_date) do
          {:ok, naive} ->
            {:ok, DateTime.from_naive!(NaiveDateTime.truncate(naive, :second), "Etc/UTC")}

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
