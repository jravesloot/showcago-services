# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :showcago_services, :scopes,
  user: [
    default: true,
    module: ShowcagoServices.Users.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: ShowcagoServices.UsersFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :showcago_services,
  ecto_repos: [ShowcagoServices.Repo],
  generators: [timestamp_type: :utc_datetime]

config :showcago_services, :telegram_bot_token, nil
config :showcago_services, :github_app_id, nil
config :showcago_services, :github_app_private_key, nil
config :showcago_services, :github_app_installation_id, nil

config :showcago_services, :github_repo, %{
  owner: "jravesloot",
  repo: "showcago-services",
  base_branch: "main"
}

config :tesla,
  adapter: {Tesla.Adapter.Finch, name: ShowcagoServices.TelegramFinch, receive_timeout: 40_000}

config :showcago_services, ShowcagoServices.Repo, migration_timestamps: [type: :utc_datetime]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Configure the endpoint
config :showcago_services, ShowcagoServicesWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ShowcagoServicesWeb.ErrorHTML, json: ShowcagoServicesWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ShowcagoServices.PubSub,
  live_view: [signing_salt: "jtC48pKo"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :showcago_services, ShowcagoServices.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  showcago_services: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  showcago_services: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Jido
config :showcago_services, ShowcagoServices.Jido,
  max_tasks: 100,
  agent_pools: []

config :jido_ai,
  model_aliases: %{
    fast: "anthropic:claude-sonnet-4-6",
    capable: "anthropic:claude-opus-4-6"
  }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
