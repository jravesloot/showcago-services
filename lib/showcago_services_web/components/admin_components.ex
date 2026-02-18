defmodule ShowcagoServicesWeb.AdminComponents do
  @moduledoc """
  Shared UI components for the admin area.
  """

  use ShowcagoServicesWeb, :html

  attr :active_page, :atom, required: true
  slot :inner_block, required: true

  def admin_layout(assigns) do
    ~H"""
    <div class="px-4 py-8 sm:px-6 lg:px-8">
      <div class="flex flex-col gap-6 lg:flex-row">
        <aside class="h-fit w-full rounded-2xl border border-slate-200 bg-white p-4 shadow-sm lg:sticky lg:top-6 lg:w-64 lg:shrink-0">
          <div class="mb-4 border-b border-slate-100 pb-3">
            <p class="text-xs font-semibold uppercase tracking-wide text-slate-500">Admin</p>
            <h2 class="mt-1 text-lg font-semibold text-slate-900">Showcago Services</h2>
          </div>

          <nav class="space-y-1" aria-label="Admin navigation">
            <.link
              navigate={~p"/admin/artists"}
              class={[
                "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                @active_page == :artists && "bg-blue-50 text-blue-700",
                @active_page != :artists && "text-slate-700 hover:bg-slate-100 hover:text-slate-900"
              ]}
            >
              <.icon name="hero-musical-note" class="size-4" />
              <span>Artists</span>
            </.link>

            <.link
              navigate={~p"/admin/venues"}
              class={[
                "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                @active_page == :venues && "bg-blue-50 text-blue-700",
                @active_page != :venues && "text-slate-700 hover:bg-slate-100 hover:text-slate-900"
              ]}
            >
              <.icon name="hero-map-pin" class="size-4" />
              <span>Venues</span>
            </.link>

            <.link
              navigate={~p"/admin/shows"}
              class={[
                "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                @active_page == :shows && "bg-blue-50 text-blue-700",
                @active_page != :shows && "text-slate-700 hover:bg-slate-100 hover:text-slate-900"
              ]}
            >
              <.icon name="hero-calendar-days" class="size-4" />
              <span>Shows</span>
            </.link>
          </nav>
        </aside>

        <section class="min-w-0 flex-1">
          {render_slot(@inner_block)}
        </section>
      </div>
    </div>
    """
  end
end
