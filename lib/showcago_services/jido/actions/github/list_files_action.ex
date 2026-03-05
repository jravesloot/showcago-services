defmodule ShowcagoServices.Jido.Actions.GitHub.ListFilesAction do
  @moduledoc false
  use Jido.Action,
    name: "list_github_files",
    description:
      "Lists files in a directory of the GitHub repository. " <>
        "Defaults to the venue sources directory.",
    schema: [
      path: [
        type: :string,
        required: false,
        default: "lib/showcago_services/venues/sources",
        doc: "The directory path relative to the repo root"
      ]
    ]

  alias ShowcagoServices.GitHub

  @impl true
  def run(params, _context) do
    path = Map.get(params, :path, "lib/showcago_services/venues/sources")
    %{owner: owner, repo: repo} = GitHub.repo_config()

    case GitHub.get("/repos/#{owner}/#{repo}/contents/#{path}") do
      {:ok, entries} when is_list(entries) ->
        files =
          Enum.map(entries, fn entry ->
            %{name: entry["name"], type: entry["type"], path: entry["path"]}
          end)

        {:ok, %{files: files}}

      {:error, reason} ->
        {:error, "Failed to list files at #{path}: #{inspect(reason)}"}
    end
  end
end
