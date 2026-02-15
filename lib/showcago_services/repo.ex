defmodule ShowcagoServices.Repo do
  use Ecto.Repo,
    otp_app: :showcago_services,
    adapter: Ecto.Adapters.Postgres
end
