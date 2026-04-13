defmodule ShowcagoServicesWeb.Router do
  use ShowcagoServicesWeb, :router

  import ShowcagoServicesWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ShowcagoServicesWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ShowcagoServicesWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", ShowcagoServicesWeb do
    pipe_through [:browser, :require_admin_user]

    live_session :require_admin_user,
      on_mount: [{ShowcagoServicesWeb.UserAuth, :require_admin}] do
      live "/admin/artists", Admin.ArtistLive, :index
      live "/admin/artists/new", Admin.ArtistLive, :new
      live "/admin/artists/:id/edit", Admin.ArtistLive, :edit

      live "/admin/venues", Admin.VenueLive, :index
      live "/admin/venues/new", Admin.VenueLive, :new
      live "/admin/venues/:id/edit", Admin.VenueLive, :edit
      live "/admin/venues/:id", Admin.VenueDetailLive, :show

      live "/admin/shows", Admin.ShowLive, :index
      live "/admin/users", Admin.UserLive, :index
      live "/admin/users/:id", Admin.UserDetailLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ShowcagoServicesWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:showcago_services, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ShowcagoServicesWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ShowcagoServicesWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ShowcagoServicesWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", ShowcagoServicesWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ShowcagoServicesWeb.UserAuth, :mount_current_scope}] do
      live "/shows", ShowLive.Index, :index
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
