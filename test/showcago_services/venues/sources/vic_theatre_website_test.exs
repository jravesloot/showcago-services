defmodule ShowcagoServices.Venues.Sources.VicTheatreWebsiteTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.VicTheatreWebsite

  @sample_html """
  <div class='events content_item' id='events_6914'>
  <div class="m-eventList m-eventList__listing m-eventList__small event_list">
    <div class="eventItem entry  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="May 03 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">May </span>
            <span class="m-date__day">03</span>
            <span class="m-date__weekday"> Sun</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  ">
          <a href="https://www.jamusa.com/events/detail/japanese-breakfast-1275001" title="More Info">Japanese Breakfast</a></h3>
        <div class="meta">
          <div class="time">Doors: 7:00 PM / Show: 8:00 PM</div>
        </div>
      </div>
    </div>
    <div class="eventItem entry alt  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="May 16 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">May </span>
            <span class="m-date__day">16</span>
            <span class="m-date__weekday"> Sat</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  ">
          <a href="https://www.jamusa.com/events/detail/beach-house-1280102" title="More Info">Beach House</a></h3>
      </div>
    </div>
    <div class="eventItem entry  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="June 05 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Jun </span>
            <span class="m-date__day">05</span>
            <span class="m-date__weekday"> Fri</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  long_title">
          <a href="https://www.jamusa.com/events/detail/big-thief-1290333" title="More Info">Big Thief</a></h3>
      </div>
    </div>
  </div>
  </div>
  """

  describe "parse_events_from_html/1" do
    test "extracts events from real-format HTML blocks" do
      events = VicTheatreWebsite.parse_events_from_html(@sample_html)

      assert length(events) == 3

      [first, second, third] = events

      assert first["name"] == "Japanese Breakfast"
      assert first["start_date"] == "2026-05-03"
      assert first["url"] == "https://www.jamusa.com/events/detail/japanese-breakfast-1275001"

      assert second["name"] == "Beach House"
      assert second["start_date"] == "2026-05-16"

      assert third["name"] == "Big Thief"
      assert third["start_date"] == "2026-06-05"
    end

    test "handles HTML entities in event titles" do
      html = """
      <div class="eventItem entry clearfix">
        <div class="date-wrapper">
          <div class="date" aria-label="May 10 2026"></div>
        </div>
        <div class="info clearfix">
          <h3 class="title  ">
            <a href="https://www.jamusa.com/events/detail/test-1234" title="More Info">Florence &amp; The Machine</a></h3>
        </div>
      </div>
      """

      [event] = VicTheatreWebsite.parse_events_from_html(html)

      assert event["name"] == "Florence & The Machine"
      assert event["start_date"] == "2026-05-10"
    end

    test "returns empty list when no events in html" do
      html = "<html><body>No events here</body></html>"
      assert VicTheatreWebsite.parse_events_from_html(html) == []
    end

    test "skips malformed event blocks" do
      html = """
      <div class="eventItem entry clearfix">
        <div class="info clearfix">
          <h3 class="title">No date here</h3>
        </div>
      </div>
      """

      assert VicTheatreWebsite.parse_events_from_html(html) == []
    end
  end

  describe "parse_date_label/1" do
    test "parses full date with year" do
      assert {:ok, "2026-05-03"} = VicTheatreWebsite.parse_date_label("May 03 2026")
    end

    test "parses date with extra spaces" do
      assert {:ok, "2026-04-03"} = VicTheatreWebsite.parse_date_label("April  3 2026")
    end

    test "parses abbreviated month" do
      assert {:ok, "2026-06-06"} = VicTheatreWebsite.parse_date_label("June 6 2026")
    end

    test "returns error for invalid format" do
      assert :error = VicTheatreWebsite.parse_date_label("TBD")
    end

    test "returns error for invalid month" do
      assert :error = VicTheatreWebsite.parse_date_label("Foo 3 2026")
    end
  end

  describe "extract_events/1" do
    test "extracts events from valid payload" do
      payload =
        Jason.encode!(%{
          "source" => "vic_theatre_website",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{
              "name" => "Japanese Breakfast",
              "start_date" => "2026-05-03",
              "url" => "https://www.jamusa.com/events/detail/japanese-breakfast-1275001"
            },
            %{
              "name" => "Big Thief",
              "start_date" => "2026-06-05",
              "url" => "https://www.jamusa.com/events/detail/big-thief-1290333"
            }
          ]
        })

      events = VicTheatreWebsite.extract_events(payload)
      assert length(events) == 2
      assert Enum.at(events, 0).name == "Japanese Breakfast"
      assert Enum.at(events, 0).url == "https://www.jamusa.com/events/detail/japanese-breakfast-1275001"
      assert Enum.at(events, 1).name == "Big Thief"
    end

    test "deduplicates events by url" do
      payload =
        Jason.encode!(%{
          "source" => "vic_theatre_website",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{
              "name" => "Japanese Breakfast",
              "start_date" => "2026-05-03",
              "url" => "https://www.jamusa.com/events/detail/japanese-breakfast-1275001"
            },
            %{
              "name" => "Japanese Breakfast",
              "start_date" => "2026-05-03",
              "url" => "https://www.jamusa.com/events/detail/japanese-breakfast-1275001"
            }
          ]
        })

      events = VicTheatreWebsite.extract_events(payload)
      assert length(events) == 1
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert VicTheatreWebsite.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert VicTheatreWebsite.extract_events("not json") == []
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert VicTheatreWebsite.source_key() == "vic_theatre_website"
    end

    test "returns correct venue_name" do
      assert VicTheatreWebsite.venue_name() == "The Vic Theatre"
    end

    test "returns positive refresh interval" do
      assert VicTheatreWebsite.default_refresh_interval_seconds() > 0
    end
  end
end
