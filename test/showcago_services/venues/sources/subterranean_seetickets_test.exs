defmodule ShowcagoServices.Venues.Sources.SubterraneanSeeTicketsTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.SubterraneanSeeTickets

  describe "parse_events_from_html/1" do
    test "extracts events from real-format HTML blocks" do
      html = """
      <ul class="seetickets-list-events">
        <li class="mdc-card display-flex mt-12 mb-12 seetickets-list-event-container mdc-card--outlined">
          <div class="seetickets-list-view-event-image-container">
            <a href="https://wl.seetickets.us/event/skizzy-mars/676612?afflky=BKBGManagementCo" target="_blank">
              <img src="img.jpg" alt="Skizzy Mars" class="seetickets-list-view-event-image">
            </a>
          </div>
          <div class="seetickets-list-event-content-container position-relative ml-2r">
            <div class="event-info-block">
              <p class="fs-12 event-header"></p>
              <p class="fs-18 bold mb-12 event-title"><a href="https://wl.seetickets.us/event/skizzy-mars/676612?afflky=BKBGManagementCo" target="_blank">Skizzy Mars</a></p>
              <p class="fs-12 supporting-talent">KEENAN TREVON, MOONLANDER</p>
              <p class="fs-12 venue">at Subterranean</p>
              <p class="fs-18 bold mt-1r event-date">Wed Apr 08</p>
              <p class="fs-12 headliners">Skizzy Mars</p>
              <p class="fs-12 doortime-showtime"><span class="door-time">Doors: 7:00 PM / </span><span class="event-time">Show: 8:00 PM</span></p>
              <p class="fs-12 prices-age"><span class="ages">17+, </span></p>
              <p class="fs-12 genre">Hip Hop</p>
            </div>
          </div>
        </li>
        <li class="mdc-card display-flex mt-12 mb-12 seetickets-list-event-container mdc-card--outlined">
          <div class="seetickets-list-view-event-image-container">
            <a href="https://wl.seetickets.us/event/letdown/678785?afflky=BKBGManagementCo" target="_blank">
              <img src="img2.jpg" alt="LETDOWN." class="seetickets-list-view-event-image">
            </a>
          </div>
          <div class="seetickets-list-event-content-container position-relative ml-2r">
            <div class="event-info-block">
              <p class="fs-12 event-header"></p>
              <p class="fs-18 bold mb-12 event-title"><a href="https://wl.seetickets.us/event/letdown/678785?afflky=BKBGManagementCo" target="_blank">LETDOWN.</a></p>
              <p class="fs-12 supporting-talent">BLAME MY YOUTH, YOUTHYEAR, LUCHIANO</p>
              <p class="fs-12 venue">at Subterranean</p>
              <p class="fs-18 bold mt-1r event-date">Fri Apr 10</p>
              <p class="fs-12 headliners">LETDOWN.</p>
              <p class="fs-12 doortime-showtime"><span class="door-time">Doors: 7:00 PM / </span><span class="event-time">Show: 8:00 PM</span></p>
              <p class="fs-12 prices-age"><span class="ages">17+, </span></p>
              <p class="fs-12 genre">Rock</p>
            </div>
          </div>
        </li>
      </ul>
      """

      events = SubterraneanSeeTickets.parse_events_from_html(html)

      assert length(events) == 2

      [first, second] = events

      assert first["name"] == "Skizzy Mars"
      assert first["url"] == "https://wl.seetickets.us/event/skizzy-mars/676612?afflky=BKBGManagementCo"
      assert String.ends_with?(first["start_date"], "-04-08")

      assert second["name"] == "LETDOWN."
      assert second["url"] == "https://wl.seetickets.us/event/letdown/678785?afflky=BKBGManagementCo"
      assert String.ends_with?(second["start_date"], "-04-10")
    end

    test "handles multi-day date format" do
      html = """
      <li class="seetickets-list-event-container">
        <div class="seetickets-list-event-content-container">
          <div class="event-info-block">
            <p class="fs-18 bold mb-12 event-title"><a href="https://wl.seetickets.us/event/distress-fest-2-day-pass/683987?afflky=BKBGManagementCo">Distress Fest - 2 Day Pass</a></p>
            <p class="fs-18 bold mt-1r event-date">Jun 27 - Jun 28</p>
          </div>
        </div>
      </li>
      """

      events = SubterraneanSeeTickets.parse_events_from_html(html)
      assert length(events) == 1

      [event] = events
      assert event["name"] == "Distress Fest - 2 Day Pass"
      assert String.ends_with?(event["start_date"], "-06-27")
    end

    test "returns empty list when no events in html" do
      html = "<html><body>No events here</body></html>"
      assert SubterraneanSeeTickets.parse_events_from_html(html) == []
    end

    test "skips malformed event blocks" do
      html = """
      <li class="seetickets-list-event-container">
        <div class="event-info-block">
          <p class="fs-18 bold mb-12 event-title">No link here</p>
          <p class="fs-18 bold mt-1r event-date">Sat Apr 11</p>
        </div>
      </li>
      """

      assert SubterraneanSeeTickets.parse_events_from_html(html) == []
    end
  end

  describe "parse_date_text/1" do
    test "parses standard day-month-date format" do
      assert {:ok, date_str} = SubterraneanSeeTickets.parse_date_text("Tue Apr 07")
      assert String.ends_with?(date_str, "-04-07")
    end

    test "parses multi-day range format" do
      assert {:ok, date_str} = SubterraneanSeeTickets.parse_date_text("Jun 27 - Jun 28")
      assert String.ends_with?(date_str, "-06-27")
    end

    test "returns error for unrecognized format" do
      assert :error = SubterraneanSeeTickets.parse_date_text("TBD")
    end
  end

  describe "extract_events/1" do
    test "extracts events from valid payload" do
      payload =
        Jason.encode!(%{
          "source" => "subterranean_seetickets",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{"name" => "Skizzy Mars", "start_date" => "2026-04-08", "url" => "https://example.com/skizzy"},
            %{"name" => "LETDOWN.", "start_date" => "2026-04-10", "url" => nil}
          ]
        })

      events = SubterraneanSeeTickets.extract_events(payload)
      assert length(events) == 2
      assert Enum.at(events, 0).name == "Skizzy Mars"
      assert Enum.at(events, 0).url == "https://example.com/skizzy"
      assert Enum.at(events, 1).name == "LETDOWN."
    end

    test "deduplicates events by name and start_date" do
      payload =
        Jason.encode!(%{
          "source" => "subterranean_seetickets",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{"name" => "Dupe Show", "start_date" => "2026-04-11", "url" => "https://a.com"},
            %{"name" => "Dupe Show", "start_date" => "2026-04-11", "url" => "https://b.com"}
          ]
        })

      events = SubterraneanSeeTickets.extract_events(payload)
      assert length(events) == 1
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert SubterraneanSeeTickets.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert SubterraneanSeeTickets.extract_events("not json") == []
    end
  end

  describe "collect_payload/2" do
    test "uses injected fetch function" do
      events = [
        %{"name" => "Test Show", "start_date" => "2026-04-10", "url" => "https://example.com"}
      ]

      {:ok, payload} =
        SubterraneanSeeTickets.collect_payload(nil, fetch_events_fun: fn -> {:ok, events} end)

      decoded = Jason.decode!(payload)
      assert decoded["source"] == "subterranean_seetickets"
      assert length(decoded["events"]) == 1
      assert Enum.at(decoded["events"], 0)["name"] == "Test Show"
    end

    test "returns error on fetch failure" do
      assert {:error, :timeout} =
               SubterraneanSeeTickets.collect_payload(nil, fetch_events_fun: fn -> {:error, :timeout} end)
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert SubterraneanSeeTickets.source_key() == "subterranean_seetickets"
    end

    test "returns correct venue_name" do
      assert SubterraneanSeeTickets.venue_name() == "Subterranean"
    end

    test "returns positive refresh interval" do
      assert SubterraneanSeeTickets.default_refresh_interval_seconds() > 0
    end
  end
end
