defmodule ShowcagoServices.Venues.Sources.MetroWebsiteTest do
  use ExUnit.Case, async: true

  alias ShowcagoServices.Venues.Sources.MetroWebsite

  describe "parse_events_from_html/1" do
    test "extracts upcoming and just announced Metro events and deduplicates by url" do
      html = """
      <div class = "col-12 eventWrapper rhpSingleEvent py-4 px-0 rhp-event__single-event--list">
        <div id="eventDate" class = "mb-0 eventMonth singleEventDate text-uppercase ">
          Fri, Mar 27
        </div>
        <a id = "eventTitle" class="url" href="https://metrochicago.com/event/nothing/metro-chicago/chicago-illinois/" title="Nothing" rel="bookmark">
          <h2>Nothing</h2>
        </a>
      </div>

      <div class="col-12 p-0 rhp-events-list-widget-events">
        <div class = "mb-2 eventDate eventMonth text-uppercase font0by875" >
          mon, May 18
        </div>
        <h4 class="entry-title summary mb-0">
          <a href="https://metrochicago.com/event/yebba-2/metro-chicago/chicago-illinois/" rel="bookmark">
            Yebba
          </a>
        </h4>
      </div>

      <div class="col-12 p-0 rhp-events-list-widget-events">
        <div class = "mb-2 eventDate eventMonth text-uppercase font0by875" >
          mon, May 18
        </div>
        <h4 class="entry-title summary mb-0">
          <a href="https://metrochicago.com/event/yebba-2/metro-chicago/chicago-illinois/" rel="bookmark">
            Yebba
          </a>
        </h4>
      </div>
      """

      events = MetroWebsite.parse_events_from_html(html)

      assert length(events) == 2

      assert Enum.any?(events, fn event ->
               event["name"] == "Nothing" and
                 event["url"] == "https://metrochicago.com/event/nothing/metro-chicago/chicago-illinois/"
             end)

      assert Enum.any?(events, fn event ->
               event["name"] == "Yebba" and
                 event["url"] == "https://metrochicago.com/event/yebba-2/metro-chicago/chicago-illinois/"
             end)
    end

    test "normalizes html entities in event titles" do
      html = """
      <div class = "col-12 eventWrapper rhpSingleEvent py-4 px-0 rhp-event__single-event--list">
        <div id="eventDate">Fri, Apr 10</div>
        <a id = "eventTitle" class="url" href="https://metrochicago.com/event/lee-fields-monophonics/metro-chicago/chicago-illinois/" title="Lee Fields &#038; Monophonics" rel="bookmark">
          <h2>Lee Fields &#038; Monophonics</h2>
        </a>
      </div>
      """

      [event] = MetroWebsite.parse_events_from_html(html)

      assert event["name"] == "Lee Fields & Monophonics"
    end
  end

  describe "parse_date_label/1" do
    test "parses Metro date labels" do
      assert {:ok, date_str} = MetroWebsite.parse_date_label("Fri, Mar 27")
      assert String.ends_with?(date_str, "-03-27")
    end

    test "returns error for invalid labels" do
      assert :error = MetroWebsite.parse_date_label("TBA")
    end
  end

  describe "extract_events/1" do
    test "extracts events from Metro website payload" do
      payload =
        Jason.encode!(%{
          "source" => "metro_website_html",
          "fetched_at" => "2026-03-24T00:00:00Z",
          "events" => [
            %{
              "name" => "Yebba",
              "start_date" => "2026-05-18",
              "url" => "https://metrochicago.com/event/yebba-2/metro-chicago/chicago-illinois/"
            }
          ]
        })

      [event] = MetroWebsite.extract_events(payload)

      assert event.name == "Yebba"
      assert event.start_date == "2026-05-18"
    end

    test "keeps compatibility with old ticketmaster payloads" do
      payload =
        Jason.encode!(%{
          "source" => "metro_ticketmaster_api",
          "fetched_at" => "2026-03-24T00:00:00Z",
          "events" => [
            %{
              "name" => "Yebba",
              "url" => "https://www.ticketmaster.com/event/Z7r9jZ1A7-N7d",
              "dates" => %{"start" => %{"dateTime" => "2026-05-20T00:30:00Z"}}
            }
          ]
        })

      [event] = MetroWebsite.extract_events(payload)

      assert event.name == "Yebba"
      assert event.url == "https://www.ticketmaster.com/event/Z7r9jZ1A7-N7d"
      assert event.start_date == "2026-05-20T00:30:00Z"
    end
  end
end
