defmodule ShowcagoServices.Venues.Sources.SleepingVillageDiceTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.SleepingVillageDice

  describe "extract_events/1" do
    test "extracts events from valid Dice API payload" do
      payload =
        Jason.encode!(%{
          "source" => "sleeping_village_dice_api",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{
              "name" => "Food House",
              "date" => "2026-04-07T02:00:00Z",
              "perm_name" => "food-house-apr-7-sleeping-village-chicago-tickets",
              "url" => "https://dice.fm/event/food-house-apr-7-sleeping-village-chicago-tickets"
            },
            %{
              "name" => "Six Sex USA Tour 2026",
              "date" => "2026-04-08T02:00:00Z",
              "perm_name" => "six-sex-usa-tour-2026-night-1",
              "url" => nil
            }
          ]
        })

      events = SleepingVillageDice.extract_events(payload)
      assert length(events) == 2

      [first, second] = events
      assert first.name == "Food House"
      assert first.start_date == "2026-04-07T02:00:00Z"
      assert first.url == "https://dice.fm/event/food-house-apr-7-sleeping-village-chicago-tickets"

      assert second.name == "Six Sex USA Tour 2026"
      assert second.start_date == "2026-04-08T02:00:00Z"
      assert second.url == "https://dice.fm/event/six-sex-usa-tour-2026-night-1"
    end

    test "uses url field when perm_name is missing" do
      payload =
        Jason.encode!(%{
          "source" => "sleeping_village_dice_api",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{
              "name" => "Some Show",
              "date" => "2026-05-01T02:00:00Z",
              "url" => "https://dice.fm/event/some-show"
            }
          ]
        })

      events = SleepingVillageDice.extract_events(payload)
      assert length(events) == 1
      assert Enum.at(events, 0).url == "https://dice.fm/event/some-show"
    end

    test "deduplicates events by name and start_date" do
      payload =
        Jason.encode!(%{
          "source" => "sleeping_village_dice_api",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{"name" => "Dupe Show", "date" => "2026-04-10T02:00:00Z", "perm_name" => "dupe-1"},
            %{"name" => "Dupe Show", "date" => "2026-04-10T02:00:00Z", "perm_name" => "dupe-2"}
          ]
        })

      events = SleepingVillageDice.extract_events(payload)
      assert length(events) == 1
    end

    test "skips events missing name or date" do
      payload =
        Jason.encode!(%{
          "source" => "sleeping_village_dice_api",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{"name" => nil, "date" => "2026-04-10T02:00:00Z"},
            %{"name" => "Valid Show", "date" => nil},
            %{"other_field" => "no name or date"},
            %{"name" => "Good Show", "date" => "2026-04-11T02:00:00Z"}
          ]
        })

      events = SleepingVillageDice.extract_events(payload)
      assert length(events) == 1
      assert Enum.at(events, 0).name == "Good Show"
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert SleepingVillageDice.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert SleepingVillageDice.extract_events("not json") == []
    end
  end

  describe "collect_payload/2" do
    test "uses injected fetch function" do
      events = [
        %{"name" => "Test Show", "date" => "2026-04-10T02:00:00Z", "perm_name" => "test-show"}
      ]

      {:ok, payload} =
        SleepingVillageDice.collect_payload(nil, fetch_events_fun: fn -> {:ok, events} end)

      decoded = Jason.decode!(payload)
      assert decoded["source"] == "sleeping_village_dice_api"
      assert length(decoded["events"]) == 1
      assert Enum.at(decoded["events"], 0)["name"] == "Test Show"
    end

    test "returns error on fetch failure" do
      assert {:error, :timeout} =
               SleepingVillageDice.collect_payload(nil, fetch_events_fun: fn -> {:error, :timeout} end)
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert SleepingVillageDice.source_key() == "sleeping_village_dice"
    end

    test "returns correct venue_name" do
      assert SleepingVillageDice.venue_name() == "Sleeping Village"
    end

    test "returns positive refresh interval" do
      assert SleepingVillageDice.default_refresh_interval_seconds() > 0
    end
  end
end
