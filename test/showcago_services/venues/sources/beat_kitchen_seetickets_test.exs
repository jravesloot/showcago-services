defmodule ShowcagoServices.Venues.Sources.BeatKitchenSeeTicketsTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.BeatKitchenSeeTickets

  describe "parse_events_from_html/1" do
    test "extracts events from real-format HTML blocks" do
      html = """
      <ul class="seetickets-list-events">
        <li class="mdc-card display-flex mt-12 mb-12 seetickets-list-event-container mdc-card--outlined">
          <div class="seetickets-list-view-event-image-container">
            <a href="https://wl.seetickets.us/event/the-queers/674831?afflky=BKBGManagementCo" target="_blank">
              <img src="img.jpg" alt="The Queers" class="seetickets-list-view-event-image">
            </a>
          </div>
          <div class="seetickets-list-event-content-container position-relative ml-2r">
            <div class="event-info-block">
              <p class="fs-12 event-header"></p>
              <p class="fs-18 bold mb-12 event-title"><a href="https://wl.seetickets.us/event/the-queers/674831?afflky=BKBGManagementCo" target="_blank">The Queers</a></p>
              <p class="fs-12 supporting-talent">THE RAGING NATHANS, VALLENCOURT</p>
              <p class="fs-12 venue">at Beat Kitchen</p>
              <p class="fs-18 bold mt-1r event-date">Fri Mar 13</p>
              <p class="fs-12 headliners">The Queers</p>
              <p class="fs-12 doortime-showtime"><span class="door-time">Doors: 7:00 PM / </span><span class="event-time">Show: 8:00 PM</span></p>
              <p class="fs-12 prices-age"><span class="ages">17+, </span></p>
              <p class="fs-12 genre">Punk</p>
            </div>
          </div>
        </li>
        <li class="mdc-card display-flex mt-12 mb-12 seetickets-list-event-container mdc-card--outlined">
          <div class="seetickets-list-view-event-image-container">
            <a href="https://wl.seetickets.us/event/bluegrass-brunch/681943?afflky=BKBGManagementCo" target="_blank">
              <img src="img2.jpg" alt="Bluegrass Brunch" class="seetickets-list-view-event-image">
            </a>
          </div>
          <div class="seetickets-list-event-content-container position-relative ml-2r">
            <div class="event-info-block">
              <p class="fs-12 event-header"></p>
              <p class="fs-18 bold mb-12 event-title"><a href="https://wl.seetickets.us/event/bluegrass-brunch/681943?afflky=BKBGManagementCo" target="_blank">Bluegrass Brunch</a></p>
              <p class="fs-12 supporting-talent"></p>
              <p class="fs-12 venue">at Beat Kitchen</p>
              <p class="fs-18 bold mt-1r event-date">Sat Mar 14</p>
              <p class="fs-12 headliners">Bluegrass Brunch</p>
              <p class="fs-12 doortime-showtime"><span class="door-time">Doors: 11:00 AM / </span><span class="event-time">Show: 11:00 AM</span></p>
              <p class="fs-12 prices-age"><span class="ages">All Ages, </span></p>
              <p class="fs-12 genre">Bluegrass</p>
            </div>
          </div>
        </li>
      </ul>
      """

      events = BeatKitchenSeeTickets.parse_events_from_html(html)

      assert length(events) == 2

      [first, second] = events

      assert first["name"] == "The Queers"
      assert first["url"] == "https://wl.seetickets.us/event/the-queers/674831?afflky=BKBGManagementCo"
      assert String.ends_with?(first["start_date"], "-03-13")

      assert second["name"] == "Bluegrass Brunch"
      assert second["url"] == "https://wl.seetickets.us/event/bluegrass-brunch/681943?afflky=BKBGManagementCo"
      assert String.ends_with?(second["start_date"], "-03-14")
    end

    test "handles multi-day date format" do
      html = """
      <li class="seetickets-list-event-container">
        <div class="seetickets-list-event-content-container">
          <div class="event-info-block">
            <p class="fs-18 bold mb-12 event-title"><a href="https://wl.seetickets.us/event/inept-2-day-pass/677390?afflky=BKBGManagementCo">Inept - 2 DAY PASS</a></p>
            <p class="fs-18 bold mt-1r event-date">May 22 - May 23</p>
          </div>
        </div>
      </li>
      """

      events = BeatKitchenSeeTickets.parse_events_from_html(html)
      assert length(events) == 1

      [event] = events
      assert event["name"] == "Inept - 2 DAY PASS"
      assert String.ends_with?(event["start_date"], "-05-22")
    end

    test "returns empty list when no events in html" do
      html = "<html><body>No events here</body></html>"
      assert BeatKitchenSeeTickets.parse_events_from_html(html) == []
    end

    test "skips malformed event blocks" do
      html = """
      <li class="seetickets-list-event-container">
        <div class="event-info-block">
          <p class="fs-18 bold mb-12 event-title">No link here</p>
          <p class="fs-18 bold mt-1r event-date">Sat Mar 14</p>
        </div>
      </li>
      """

      assert BeatKitchenSeeTickets.parse_events_from_html(html) == []
    end
  end

  describe "parse_date_text/1" do
    test "parses standard day-month-date format" do
      assert {:ok, date_str} = BeatKitchenSeeTickets.parse_date_text("Sat Mar 07")
      assert String.ends_with?(date_str, "-03-07")
    end

    test "parses multi-day range format" do
      assert {:ok, date_str} = BeatKitchenSeeTickets.parse_date_text("May 22 - May 23")
      assert String.ends_with?(date_str, "-05-22")
    end

    test "returns error for unrecognized format" do
      assert :error = BeatKitchenSeeTickets.parse_date_text("TBD")
    end
  end

  describe "extract_events/1" do
    test "extracts events from valid payload" do
      payload =
        Jason.encode!(%{
          "source" => "beat_kitchen_seetickets",
          "fetched_at" => "2025-03-07T00:00:00Z",
          "events" => [
            %{"name" => "The Queers", "start_date" => "2025-03-13", "url" => "https://example.com/queers"},
            %{"name" => "Bluegrass Brunch", "start_date" => "2025-03-14", "url" => nil}
          ]
        })

      events = BeatKitchenSeeTickets.extract_events(payload)
      assert length(events) == 2
      assert Enum.at(events, 0).name == "The Queers"
      assert Enum.at(events, 0).url == "https://example.com/queers"
      assert Enum.at(events, 1).name == "Bluegrass Brunch"
    end

    test "deduplicates events by name and start_date" do
      payload =
        Jason.encode!(%{
          "source" => "beat_kitchen_seetickets",
          "fetched_at" => "2025-03-07T00:00:00Z",
          "events" => [
            %{"name" => "Dupe Show", "start_date" => "2025-03-14", "url" => "https://a.com"},
            %{"name" => "Dupe Show", "start_date" => "2025-03-14", "url" => "https://b.com"}
          ]
        })

      events = BeatKitchenSeeTickets.extract_events(payload)
      assert length(events) == 1
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert BeatKitchenSeeTickets.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert BeatKitchenSeeTickets.extract_events("not json") == []
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert BeatKitchenSeeTickets.source_key() == "beat_kitchen_seetickets"
    end

    test "returns correct venue_name" do
      assert BeatKitchenSeeTickets.venue_name() == "Beat Kitchen"
    end

    test "returns positive refresh interval" do
      assert BeatKitchenSeeTickets.default_refresh_interval_seconds() > 0
    end
  end
end
