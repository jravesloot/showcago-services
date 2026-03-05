[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter, Styler],
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs", "priv/repo/migrations/*.exs", "priv/repo/migrations/.formatter.exs", "*.heex"]
]
