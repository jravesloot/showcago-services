defmodule ShowcagoServices.Venues.Sources.RivieraTheatreWebsiteTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.RivieraTheatreWebsite

  @sample_html """
  <div class='events content_item' id='events_6914'>
  <div class="m-eventList m-eventList__listing m-eventList__small event_list">
    <div class="eventItem entry  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="April 11 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Apr </span>
            <span class="m-date__day">11</span>
            <span class="m-date__weekday"> Sat</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  ">
          <a href="https://www.jamusa.com/events/detail/snail-mail-1273351" title="More Info">Snail Mail</a></h3>
        <div class="meta">
          <div class="time">Doors: 6:00 PM / Show: 7:30 PM</div>
        </div>
      </div>
    </div>
    <div class="eventItem entry alt  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="April 15 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Apr </span>
            <span class="m-date__day">15</span>
            <span class="m-date__weekday"> Wed</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  ">
          <a href="https://www.jamusa.com/events/detail/an-evening-with-john-butler-with-band-1283576" title="More Info">An Evening With John Butler With Band</a></h3>
      </div>
    </div>
    <div class="eventItem entry  clearfix" >
      <div class="date-wrapper">
        <div class="date" aria-label="April 21 2026">
          <span class="m-date__singleDate">
            <span class="m-date__month">Apr </span>
            <span class="m-date__day">21</span>
            <span class="m-date__weekday"> Tue</span>
          </span>
        </div>
      </div>
      <div class="info clearfix">
        <h3 class="title  long_title">
          <a href="https://www.jamusa.com/events/detail/oh-wonder-1285550" title="More Info">OH WONDER</a></h3>
      </div>
    </div>
  </div>
  </div>
  """

  describe "parse_events_from_html/1" do
    test "extracts events from real-format HTML blocks" do
      events = RivieraTheatreWebsite.parse_events_from_html(@sample_html)

      assert length(events) == 3

      [first, second, third] = events

      assert first["name"] == "Snail Mail"
      assert first["start_date"] == "2026-04-11"
      assert first["url"] == "https://www.jamusa.com/events/detail/snail-mail-1273351"

      assert second["name"] == "An Evening With John Butler With Band"
      assert second["start_date"] == "2026-04-15"

      assert third["name"] == "OH WONDER"
      assert third["start_date"] == "2026-04-21"
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

      [event] = RivieraTheatreWebsite.parse_events_from_html(html)

      assert event["name"] == "Florence & The Machine"
      assert event["start_date"] == "2026-05-10"
    end

    test "returns empty list when no events in html" do
      html = "<html><body>No events here</body></html>"
      assert RivieraTheatreWebsite.parse_events_from_html(html) == []
    end

    test "skips malformed event blocks" do
      html = """
      <div class="eventItem entry clearfix">
        <div class="info clearfix">
          <h3 class="title">No date here</h3>
        </div>
      </div>
      """

      assert RivieraTheatreWebsite.parse_events_from_html(html) == []
    end
  end

  describe "parse_date_label/1" do
    test "parses full date with year" do
      assert {:ok, "2026-04-11"} = RivieraTheatreWebsite.parse_date_label("April 11 2026")
    end

    test "parses date with extra spaces" do
      assert {:ok, "2026-04-03"} = RivieraTheatreWebsite.parse_date_label("April  3 2026")
    end

    test "parses abbreviated month" do
      assert {:ok, "2026-06-06"} = RivieraTheatreWebsite.parse_date_label("June 6 2026")
    end

    test "returns error for invalid format" do
      assert :error = RivieraTheatreWebsite.parse_date_label("TBD")
    end

    test "returns error for invalid month" do
      assert :error = RivieraTheatreWebsite.parse_date_label("Foo 3 2026")
    end
  end

  describe "extract_events/1" do
    test "extracts events from valid payload" do
      payload =
        Jason.encode!(%{
          "source" => "riviera_theatre_website",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{
              "name" => "Snail Mail",
              "start_date" => "2026-04-11",
              "url" => "https://www.jamusa.com/events/detail/snail-mail-1273351"
            },
            %{
              "name" => "OH WONDER",
              "start_date" => "2026-04-21",
              "url" => "https://www.jamusa.com/events/detail/oh-wonder-1285550"
            }
          ]
        })

      events = RivieraTheatreWebsite.extract_events(payload)
      assert length(events) == 2
      assert Enum.at(events, 0).name == "Snail Mail"
      assert Enum.at(events, 0).url == "https://www.jamusa.com/events/detail/snail-mail-1273351"
      assert Enum.at(events, 1).name == "OH WONDER"
    end

    test "deduplicates events by url" do
      payload =
        Jason.encode!(%{
          "source" => "riviera_theatre_website",
          "fetched_at" => "2026-04-07T00:00:00Z",
          "events" => [
            %{
              "name" => "Snail Mail",
              "start_date" => "2026-04-11",
              "url" => "https://www.jamusa.com/events/detail/snail-mail-1273351"
            },
            %{
              "name" => "Snail Mail",
              "start_date" => "2026-04-11",
              "url" => "https://www.jamusa.com/events/detail/snail-mail-1273351"
            }
          ]
        })

      events = RivieraTheatreWebsite.extract_events(payload)
      assert length(events) == 1
    end

    test "returns empty list for wrong source key" do
      payload = Jason.encode!(%{"source" => "wrong_source", "events" => []})
      assert RivieraTheatreWebsite.extract_events(payload) == []
    end

    test "returns empty list for invalid payload" do
      assert RivieraTheatreWebsite.extract_events("not json") == []
    end
  end

  describe "source behaviour" do
    test "returns correct source_key" do
      assert RivieraTheatreWebsite.source_key() == "riviera_theatre_website"
    end

    test "returns correct venue_name" do
      assert RivieraTheatreWebsite.venue_name() == "Riviera Theatre"
    end

    test "returns positive refresh interval" do
      assert RivieraTheatreWebsite.default_refresh_interval_seconds() > 0
    end
  end
end
