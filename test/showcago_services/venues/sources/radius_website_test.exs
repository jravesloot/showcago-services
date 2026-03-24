defmodule ShowcagoServices.Venues.Sources.RadiusWebsiteTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.RadiusWebsite

  @sample_html """
  <div id="eventsList" class="event_list">
    <div class="entry   clearfix ">
      <div class="thumb">
        <a href="https://www.radius-chicago.com/events/detail/1273576" title="More Info">
          <img src="https://images.example.com/img.jpg" alt=""/>
        </a>
      </div>
      <div class="info">
        <div class="title">
          <h5 class="presentedBy animated">boost+++</h5>
          <h5 class="tour"></h5>
          <h3 class="carousel_item_title_small">
            <a href="https://www.radius-chicago.com/events/detail/1273576"
              title="More Info">
              Anetha, Bad Boombox, Kirk, Ollie Lishman
            </a>
          </h3>
          <h4 class="supporting animated"></h4>
        </div>
        <div class="date-time-container">
          <span class="date">
            <span class="fa fa-calendar-o"></span>
            Fri, Mar 27, 2026
          </span>
          <span class="time">
            <span class="fa fa-clock-o"></span>
            Doors  10:00 PM
          </span>
        </div>
      </div>
      <div class="buttons">
        <a href="https://www.axs.com/events/1273576/anetha-tickets?skin=radius" title="Buy Tickets" target="_blank" class="btn-tickets tickets status_1">Buy Tickets</a>
      </div>
    </div>
    <div class="entry alt   clearfix ">
      <div class="thumb">
        <a href="https://www.radius-chicago.com/events/detail/1241065" title="More Info">
          <img src="https://images.example.com/img2.jpg" alt=""/>
        </a>
      </div>
      <div class="info">
        <div class="title">
          <h5 class="presentedBy animated"></h5>
          <h5 class="tour">Asleep in the Garden Tour</h5>
          <h3 class="carousel_item_title_small">
            <a href="https://www.radius-chicago.com/events/detail/1241065"
              title="More Info">
              Seven Lions
            </a>
          </h3>
          <h4 class="supporting animated">Jason Ross b2b Kill the Noise</h4>
        </div>
        <div class="date-time-container">
          <span class="date">
            <span class="fa fa-calendar-o"></span>
            Sat, Apr 4, 2026
          </span>
          <span class="time">
            <span class="fa fa-clock-o"></span>
            Doors  9:00 PM
          </span>
        </div>
      </div>
      <div class="buttons">
        <a href="https://www.axs.com/events/1241065/seven-lions-tickets?skin=radius" title="Buy Tickets" target="_blank" class="btn-tickets tickets status_1">Buy Tickets</a>
      </div>
    </div>
    <div class="entry   clearfix ">
      <div class="info">
        <div class="title">
          <h5 class="presentedBy animated">Cold Waves Presents: SPACE ECHO</h5>
          <h5 class="tour"></h5>
          <h3 class="carousel_item_title_small">
            <a href="https://www.radius-chicago.com/events/detail/1219962"
              title="More Info">
              Failure
            </a>
          </h3>
          <h4 class="supporting animated">Baroness &bull; Trail Of Dead</h4>
        </div>
        <div class="date-time-container">
          <span class="date">
            <span class="fa fa-calendar-o"></span>
            Sat, May 2, 2026
          </span>
        </div>
      </div>
    </div>
  </div>
  """

  describe "parse_events_from_html/1" do
    test "extracts events from real-format HTML blocks" do
      events = RadiusWebsite.parse_events_from_html(@sample_html)

      assert length(events) == 3

      [first, second, third] = events

      assert first["name"] == "Anetha, Bad Boombox, Kirk, Ollie Lishman"
      assert first["start_date"] == "2026-03-27"
      assert first["url"] == "https://www.radius-chicago.com/events/detail/1273576"

      assert second["name"] == "Seven Lions"
      assert second["start_date"] == "2026-04-04"
      assert second["url"] == "https://www.radius-chicago.com/events/detail/1241065"

      assert third["name"] == "Failure"
      assert third["start_date"] == "2026-05-02"
      assert third["url"] == "https://www.radius-chicago.com/events/detail/1219962"
    end

    test "handles HTML entities in event titles" do
      html = """
      <div class="entry clearfix">
        <div class="info">
          <div class="title">
            <h3 class="carousel_item_title_small">
              <a href="https://www.radius-chicago.com/events/detail/123" title="More Info">
                Oteil &amp; Friends
              </a>
            </h3>
          </div>
          <div class="date-time-container">
            <span class="date">
              <span class="fa fa-calendar-o"></span>
              Fri, Jun 6, 2026
            </span>
          </div>
        </div>
      </div>
      """

      [event] = RadiusWebsite.parse_events_from_html(html)

      assert event["name"] == "Oteil & Friends"
      assert event["start_date"] == "2026-06-06"
    end

    test "returns empty list when no events in html" do
      html = "<html><body>No events here</body></html>"
      assert RadiusWebsite.parse_events_from_html(html) == []
    end

    test "skips malformed event blocks" do
      html = """
      <div class="entry clearfix">
        <div class="info">
          <div class="title">
            <h3 class="carousel_item_title_small">Missing date</h3>
          </div>
        </div>
      </div>
      """

      assert RadiusWebsite.parse_events_from_html(html) == []
    end
  end

  describe "parse_date_text/1" do
    test "parses standard day-month-date-year format" do
      assert {:ok, "2026-03-27"} = RadiusWebsite.parse_date_text("Fri, Mar 27, 2026")
    end

    test "parses single-digit day" do
      assert {:ok, "2026-05-01"} = RadiusWebsite.parse_date_text("Fri, May 1, 2026")
    end

    test "returns error for invalid format" do
      assert :error = RadiusWebsite.parse_date_text("TBD")
    end

    test "returns error for invalid month" do
      assert :error = RadiusWebsite.parse_date_text("Fri, Foo 3, 2026")
    end
  end

  describe "extract_events/1" do
    test "extracts events from valid payload" do
      payload =
        Jason.encode!(%{
          "source" => "radius_website",
          "fetched_at" => "2026-03-24T00:00:00Z",
          "events" => [
            %{
              "name" => "Anetha, Bad Boombox, Kirk, Ollie Lishman",
              "start_date" => "2026-03-27",
              "url" => "https://www.radius-chicago.com/events/detail/1273576"
            },
            %{
              "name" => "Seven Lions",
              "start_date" => "2026-04-04",
              "url" => "https://www.radius-chicago.com/events/detail/1241065"
            }
          ]
        })

      events = RadiusWebsite.extract_events(payload)
      assert length(events) == 2
      assert Enum.at(events, 0).name == "Anetha, Bad Boombox, Kirk, Ollie Lishman"
      assert Enum.at(events, 1).name == "Seven Lions"
    end

    test "deduplicates events by url" do
      payload =
        Jason.encode!(%{
          "source" => "radius_website",
          "fetched_at" => "2026-03-24T00:00:00Z",
          "events" => [
            %{
              "name" => "Seven Lions",
              "start_date" => "2026-04-04",
              "url" => "https://www.radius-chicago.com/events/detail/1241065"
            },
            %{
              "name" => "Seven Lions",
              "start_date" => "2026-04-04",
              "url" => "https://www.radius-chicago.com/events/detail/1241065"
            }
          ]
        })

      events = RadiusWebsite.extract_events(payload)
      assert length(events) == 1
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert RadiusWebsite.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert RadiusWebsite.extract_events("not json") == []
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert RadiusWebsite.source_key() == "radius_website"
    end

    test "returns correct venue_name" do
      assert RadiusWebsite.venue_name() == "Radius Chicago"
    end

    test "returns positive refresh interval" do
      assert RadiusWebsite.default_refresh_interval_seconds() > 0
    end
  end
end
