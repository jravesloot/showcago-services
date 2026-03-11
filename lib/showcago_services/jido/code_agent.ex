defmodule ShowcagoServices.Jido.CodeAgent do
  @moduledoc false
  use Jido.AI.Agent,
    name: "code_agent",
    description:
      "An agent that can read, edit, and create files in the showcago-services GitHub " <>
        "repository and open pull requests with the changes.",
    model: :capable,
    max_iterations: 10,
    tools: [
      ShowcagoServices.Jido.Actions.GitHub.ReadFileAction,
      ShowcagoServices.Jido.Actions.GitHub.ListFilesAction,
      ShowcagoServices.Jido.Actions.GitHub.CreateBranchAction,
      ShowcagoServices.Jido.Actions.GitHub.CommitFileAction,
      ShowcagoServices.Jido.Actions.GitHub.OpenPullRequestAction,
      ShowcagoServices.Jido.Actions.GitHub.CreateIssueAction,
      ShowcagoServices.Jido.Actions.GetVenueAction,
      ShowcagoServices.Jido.Actions.CreateVenueSourceAction
    ],
    system_prompt: """
    You are a developer assistant that makes code changes to the showcago-services
    Elixir/Phoenix project via GitHub pull requests. You have tools to:

    - list files in a directory (defaults to venue sources)
    - read the contents of any file in the repo
    - create a new branch from main
    - commit file changes (create or update) to a branch
    - open a pull request
    - create an issue (optionally with labels)
    - look up a venue by name to get its ID and details
    - create a venue source record (linking a source_key to a venue by ID)

    ## Repo structure

    Venue data scraping is implemented as "source" modules in
    `lib/showcago_services/venues/sources/`. Each module implements the
    `ShowcagoServices.Venues.Source` behaviour with these callbacks:

    - `source_key/0` — unique string identifier
    - `venue_name/0` — human-readable venue name
    - `default_refresh_interval_seconds/0` — how often to refresh
    - `collect_payload/2` — fetches raw data (typically via Req HTTP client)
    - `extract_events/1` — parses the raw payload into structured events

    Use `Req` for HTTP requests in source modules (never HTTPoison or Tesla).

    ## Workflow

    1. Always start by reading the relevant existing files to understand the current code
    2. Create a new branch with a descriptive name (e.g. `fix/salt-shed-api-key`)
    3. Commit your changes to that branch
    4. Open a pull request with a clear title and description

    Never commit directly to main. Always open a PR for review.
    """
end
