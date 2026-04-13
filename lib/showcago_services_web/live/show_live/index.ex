defmodule ShowcagoServicesWeb.ShowLive.Index do
  @moduledoc false
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.Shows

  @chicago_time_zone "America/Chicago"

  def mount(_params, _session, socket) do
    grouped_shows = Shows.list_upcoming_shows_grouped_by_date()

    {:ok,
     socket
     |> assign(:page_title, "Upcoming Shows")
     |> assign(:grouped_shows, grouped_shows)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <div class="mx-auto max-w-4xl py-8">
        <div class="mb-10 text-center">
          <h1 class="text-4xl font-extrabold tracking-tight text-base-content">
            Upcoming Shows
          </h1>
          <p class="mt-3 text-lg text-base-content/60">
            Live music events across Chicago venues
          </p>
        </div>

        <div
          :if={@grouped_shows == []}
          id="no-shows"
          class="rounded-2xl border border-base-300 bg-base-200/50 px-6 py-16 text-center"
        >
          <.icon name="hero-musical-note" class="mx-auto size-12 text-base-content/30" />
          <p class="mt-4 text-lg font-medium text-base-content/70">No upcoming shows</p>
          <p class="mt-1 text-sm text-base-content/50">Check back soon for new events.</p>
        </div>

        <div :if={@grouped_shows != []} class="space-y-10">
          <section :for={{date, shows} <- @grouped_shows} id={"date-#{date}"}>
            <div class="sticky top-0 z-10 -mx-2 mb-4 px-2 py-2 backdrop-blur-sm">
              <h2 class="text-lg font-bold text-base-content">
                <time datetime={Date.to_iso8601(date)}>
                  {Calendar.strftime(date, "%A, %B %-d")}
                </time>
              </h2>
            </div>

            <ul class="space-y-3">
              <li
                :for={show <- shows}
                id={"show-#{show.id}"}
                class="group rounded-xl border border-base-300 bg-base-100 px-5 py-4 shadow-sm transition hover:shadow-md hover:border-primary/30"
              >
                <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div class="min-w-0 flex-1">
                    <p class="text-base font-semibold text-base-content">
                      {show.notes}
                    </p>
                    <div class="mt-1.5 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-base-content/60">
                      <span class="inline-flex items-center gap-1">
                        <.icon name="hero-map-pin-micro" class="size-4" />
                        {show.venue.name}
                      </span>
                      <span class="inline-flex items-center gap-1">
                        <.icon name="hero-clock-micro" class="size-4" />
                        {show_time(show)}
                      </span>
                      <span
                        :if={show.price_min || show.price_max}
                        class="inline-flex items-center gap-1"
                      >
                        <.icon name="hero-currency-dollar-micro" class="size-4" />
                        {format_price(show)}
                      </span>
                    </div>
                    <p :if={show.notes} class="mt-2 text-sm text-base-content/50">
                      {artist_names(show)}
                    </p>
                  </div>

                  <div :if={show.ticket_url} class="shrink-0">
                    <a
                      href={show.ticket_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="btn btn-primary btn-sm gap-1"
                    >
                      Tickets <.icon name="hero-arrow-top-right-on-square-micro" class="size-3.5" />
                    </a>
                  </div>
                </div>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp artist_names(show) do
    case Enum.map_join(show.artists, ", ", & &1.name) do
      "" -> show.notes || "TBA"
      names -> names
    end
  end

  defp show_time(show) do
    show.date
    |> chicago_datetime()
    |> Calendar.strftime("%-I:%M %p")
    |> Kernel.<>(" CT")
  end

  defp format_price(show) do
    case {show.price_min, show.price_max} do
      {nil, nil} -> nil
      {min, nil} -> "$#{Decimal.round(min, 0)}"
      {nil, max} -> "$#{Decimal.round(max, 0)}"
      {min, max} when min == max -> "$#{Decimal.round(min, 0)}"
      {min, max} -> "$#{Decimal.round(min, 0)}–$#{Decimal.round(max, 0)}"
    end
  end

  defp chicago_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted} -> shifted
      _ -> datetime
    end
  end
end
