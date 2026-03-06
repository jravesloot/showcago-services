defmodule ShowcagoServices.Workers.CollectVenueSourceWorkerTest do
  use ShowcagoServices.DataCase, async: true
  use Oban.Testing, repo: ShowcagoServices.Repo

  alias ShowcagoServices.Schema.VenueSource
  alias ShowcagoServices.Venues
  alias ShowcagoServices.Workers.CollectVenueSourceWorker

  describe "perform/1 skipped source" do
    test "returns :ok when source was recently collected" do
      venue = create_venue!(%{name: "Thalia Hall"})
      insert_source_config!(venue, "thalia_hall_ticketmaster")

      fetch_fun = fn ->
        {:ok,
         [
           %{
             "name" => "Test Artist",
             "url" => "https://example.com/tickets/456",
             "dates" => %{"start" => %{"dateTime" => "2026-10-01T19:00:00Z"}}
           }
         ]}
      end

      # Pre-collect with fresh data so the worker sees it as non-stale
      {:ok, _venue, :updated} =
        Venues.collect_schedule_payload_for_source("thalia_hall_ticketmaster",
          force: true,
          fetch_ticketmaster_events_fun: fetch_fun
        )

      # Worker uses force: false — data is fresh, so it skips
      assert :ok = perform_job(CollectVenueSourceWorker, %{"source_key" => "thalia_hall_ticketmaster"})
    end
  end

  describe "perform/1 error cases" do
    test "returns error when venue is not found for a known source" do
      # Venue doesn't exist but source_key is valid
      assert {:error, _reason} =
               perform_job(CollectVenueSourceWorker, %{"source_key" => "thalia_hall_ticketmaster"})
    end

    test "returns error for an unknown source key" do
      assert {:error, _reason} =
               perform_job(CollectVenueSourceWorker, %{"source_key" => "nonexistent_source"})
    end
  end

  defp create_venue!(attrs) do
    {:ok, venue} = Venues.create_venue(attrs)
    venue
  end

  defp insert_source_config!(venue, source_key) do
    %VenueSource{}
    |> VenueSource.changeset(%{
      venue_id: venue.id,
      source_key: source_key,
      enabled: true
    })
    |> Repo.insert!()
  end
end
