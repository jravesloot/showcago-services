defmodule ShowcagoServices.Venues.Sources.ParkWestWebsiteTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.ParkWestWebsite

  @sample_html """
  <div class='events content_item' id='events_6914'>
  <div class="m-eventList m-eventList__listing m-eventList__small event_list">
    <div class="eventItem entry  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="March 27 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Mar </span>
            <span class="m-date__day">27</span>
            <span class="m-date__weekday"> Fri</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  ">
          <a href="https://www.jamusa.com/events/detail/shrek-rave-1329863" title="More Info">Shrek Rave</a></h3>
        <div class="meta">
          <div class="time">Doors: 8:00 PM / Show: 9:00 PM</div>
        </div>
      </div>
    </div>
    <div class="eventItem entry alt  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="March 31 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Mar </span>
            <span class="m-date__day">31</span>
            <span class="m-date__weekday"> Tue</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  ">
          <a href="https://www.jamusa.com/events/detail/tab-benoit-samantha-fish-1304788" title="More Info">Samantha Fish + Tab Benoit</a></h3>
      </div>
    </div>
    <div class="eventItem entry  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="April  3 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Apr </span>
            <span class="m-date__day"> 3</span>
            <span class="m-date__weekday"> Fri</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  long_title">
          <a href="https://www.jamusa.com/events/detail/steely-dead-1285577" title="More Info">Steely Dead - A Sonic Fusion of The Grateful Dead and Steely Dan </a></h3>
      </div>
    </div>
  </div>
  </div>
  """

  describe "parse_events_from_html/1" do
    test "extracts events from real-format HTML blocks" do
      events = ParkWestWebsite.parse_events_from_html(@sample_html)

      assert length(events) == 3

      [first, second, third] = events

      assert first["name"] == "Shrek Rave"
      assert first["start_date"] == "2026-03-27"
      assert first["url"] == "https://www.jamusa.com/events/detail/shrek-rave-1329863"

      assert second["name"] == "Samantha Fish + Tab Benoit"
      assert second["start_date"] == "2026-03-31"

      assert third["name"] == "Steely Dead - A Sonic Fusion of The Grateful Dead and Steely Dan"
      assert third["start_date"] == "2026-04-03"
    end

    test "handles HTML entities in event titles" do
      html = """
      <div class="eventItem entry clearfix">
        <div class="date-wrapper">
          <div class="date" aria-label="April 17 2026"></div>
        </div>
        <div class="info clearfix">
          <h3 class="title  ">
            <a href="https://www.jamusa.com/events/detail/melvin-seals-jgb-1299567" title="More Info">Melvin Seals &amp; JGB</a></h3>
        </div>
      </div>
      """

      [event] = ParkWestWebsite.parse_events_from_html(html)

      assert event["name"] == "Melvin Seals & JGB"
      assert event["start_date"] == "2026-04-17"
    end

    test "returns empty list when no events in html" do
      html = "<html><body>No events here</body></html>"
      assert ParkWestWebsite.parse_events_from_html(html) == []
    end

    test "skips malformed event blocks" do
      html = """
      <div class="eventItem entry clearfix">
        <div class="info clearfix">
          <h3 class="title">No date here</h3>
        </div>
      </div>
      """

      assert ParkWestWebsite.parse_events_from_html(html) == []
    end
  end

  describe "parse_date_label/1" do
    test "parses full date with year" do
      assert {:ok, "2026-03-27"} = ParkWestWebsite.parse_date_label("March 27 2026")
    end

    test "parses date with extra spaces" do
      assert {:ok, "2026-04-03"} = ParkWestWebsite.parse_date_label("April  3 2026")
    end

    test "parses abbreviated month" do
      assert {:ok, "2026-06-06"} = ParkWestWebsite.parse_date_label("June 6 2026")
    end

    test "returns error for invalid format" do
      assert :error = ParkWestWebsite.parse_date_label("TBD")
    end

    test "returns error for invalid month" do
      assert :error = ParkWestWebsite.parse_date_label("Foo 3 2026")
    end
  end

  describe "extract_events/1" do
    test "extracts events from valid payload" do
      payload =
        Jason.encode!(%{
          "source" => "park_west_website",
          "fetched_at" => "2026-03-24T00:00:00Z",
          "events" => [
            %{
              "name" => "Shrek Rave",
              "start_date" => "2026-03-27",
              "url" => "https://www.jamusa.com/events/detail/shrek-rave-1329863"
            },
            %{
              "name" => "Samantha Fish + Tab Benoit",
              "start_date" => "2026-03-31",
              "url" => "https://www.jamusa.com/events/detail/tab-benoit-samantha-fish-1304788"
            }
          ]
        })

      events = ParkWestWebsite.extract_events(payload)
      assert length(events) == 2
      assert Enum.at(events, 0).name == "Shrek Rave"
      assert Enum.at(events, 0).url == "https://www.jamusa.com/events/detail/shrek-rave-1329863"
      assert Enum.at(events, 1).name == "Samantha Fish + Tab Benoit"
    end

    test "deduplicates events by url" do
      payload =
        Jason.encode!(%{
          "source" => "park_west_website",
          "fetched_at" => "2026-03-24T00:00:00Z",
          "events" => [
            %{
              "name" => "Shrek Rave",
              "start_date" => "2026-03-27",
              "url" => "https://www.jamusa.com/events/detail/shrek-rave-1329863"
            },
            %{
              "name" => "Shrek Rave",
              "start_date" => "2026-03-27",
              "url" => "https://www.jamusa.com/events/detail/shrek-rave-1329863"
            }
          ]
        })

      events = ParkWestWebsite.extract_events(payload)
      assert length(events) == 1
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert ParkWestWebsite.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert ParkWestWebsite.extract_events("not json") == []
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert ParkWestWebsite.source_key() == "park_west_website"
    end

    test "returns correct venue_name" do
      assert ParkWestWebsite.venue_name() == "Park West"
    end

    test "returns positive refresh interval" do
      assert ParkWestWebsite.default_refresh_interval_seconds() > 0
    end
  end
end
