defmodule ShowcagoServices.Jido.Actions.GitHub.ReadFileAction do
  use Jido.Action,
    name: "read_github_file",
    description: "Reads the contents of a file from the GitHub repository.",
    schema: [
      path: [type: :string, required: true, doc: "The file path relative to the repo root"]
    ]

  alias ShowcagoServices.GitHub

  @impl true
  def run(%{path: path}, _context) do
    %{owner: owner, repo: repo} = GitHub.repo_config()

    case GitHub.get("/repos/#{owner}/#{repo}/contents/#{path}") do
      {:ok, %{"content" => content, "sha" => sha}} ->
        decoded = content |> String.replace("\n", "") |> Base.decode64!()
        {:ok, %{path: path, content: decoded, sha: sha}}

      {:error, reason} ->
        {:error, "Failed to read file #{path}: #{inspect(reason)}"}
    end
  end
end
