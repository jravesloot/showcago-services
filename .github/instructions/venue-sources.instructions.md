---
description: "Use when working on venue sources, scrapers, event parsing, the venues collector, or adding a new venue. Covers the Source behaviour contract, payload format, collection flow, and testing patterns."
applyTo: lib/showcago_services/venues/**
---
# Venue Source Development

## Source behaviour (`ShowcagoServices.Venues.Source`)

All venue sources implement this behaviour with 5 callbacks:

    @callback source_key() :: binary()
    @callback venue_name() :: binary()
    @callback default_refresh_interval_seconds() :: pos_integer()
    @callback collect_payload(Venue.t(), keyword()) :: {:ok, binary()} | {:error, term()}
    @callback extract_events(binary()) :: [extracted_event()]

- `source_key/0` — unique identifier string (e.g. `"metro_website"`, `"aragon_ballroom_ticketmaster"`)
- `venue_name/0` — human-readable venue name
- `collect_payload/2` — fetches raw data from the venue's website or API, returns JSON string
- `extract_events/1` — parses a stored JSON payload into a list of `%{name: binary(), start_date: binary(), url: binary() | nil}`

## Source modules

Located in `lib/showcago_services/venues/sources/`. A single venue can have **multiple sources** (e.g. a Ticketmaster API feed and the venue's own website). Each source module is independent and produces its own `VenueSource` record keyed by `(venue_id, source_key)`.

Sources can be **any data provider** — an API, a website scraper, an RSS feed, a third-party ticketing platform, etc. Current examples include:

- **Ticketmaster API** — fetch from Ticketmaster Discovery API using venue-specific URLs
- **HTML scrapers** — fetch venue website HTML via Req, parse with regex. Expose a `parse_events_from_html/1` function for testability
- **SeeTickets, Dice, lh-st.com** — other ticketing platform APIs/pages

## Payload format

`collect_payload/2` must return a JSON string with this structure:

    %{
      "source" => "source_identifier_string",
      "fetched_at" => "2026-01-01T00:00:00Z",
      "events" => [%{"name" => "...", "start_date" => "...", "url" => "..."}]
    }

## Collection flow

1. `DispatchCollectionWorker` (Oban cron, daily at 5 AM) enqueues per-source jobs
2. `CollectVenueSourceWorker` calls `Venues.collect_schedule_payload_for_source/2`
3. Payload stored in `VenueSource` if stale (based on `default_refresh_interval_seconds`)
4. `Venues.parse_schedule_payload_and_create_shows_for_source/1` calls `source.extract_events/1`
5. Artist names fuzzy-matched via PostgreSQL `word_similarity()`
6. Show records created with artist relationships

## Testing pattern

- Parser tests use static HTML strings, not live HTTP requests
- `collect_payload/2` accepts `opts` with `:fetch_events_fun` for dependency injection in tests
- Test file location mirrors source: `test/showcago_services/venues/sources/<source_name>_test.exs`
