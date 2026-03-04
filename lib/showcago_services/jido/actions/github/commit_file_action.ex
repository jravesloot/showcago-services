defmodule ShowcagoServices.Jido.Actions.GitHub.CommitFileAction do
  use Jido.Action,
    name: "commit_github_file",
    description:
      "Creates or updates a file in the GitHub repository on a specified branch. " <>
        "For existing files, the current SHA is fetched automatically.",
    schema: [
      path: [type: :string, required: true, doc: "The file path relative to the repo root"],
      content: [type: :string, required: true, doc: "The full file content to commit"],
      message: [type: :string, required: true, doc: "The commit message"],
      branch: [type: :string, required: true, doc: "The branch to commit to"]
    ]

  alias ShowcagoServices.GitHub

  @impl true
  def run(%{path: path, content: content, message: message, branch: branch}, _context) do
    %{owner: owner, repo: repo} = GitHub.repo_config()

    existing_sha =
      case GitHub.get("/repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch}") do
        {:ok, %{"sha" => sha}} -> sha
        _ -> nil
      end

    body =
      %{
        message: message,
        content: Base.encode64(content),
        branch: branch
      }
      |> maybe_put_sha(existing_sha)

    case GitHub.put("/repos/#{owner}/#{repo}/contents/#{path}", body) do
      {:ok, %{"commit" => %{"sha" => commit_sha}}} ->
        {:ok, %{path: path, commit_sha: commit_sha}}

      {:error, reason} ->
        {:error, "Failed to commit file #{path}: #{inspect(reason)}"}
    end
  end

  defp maybe_put_sha(body, nil), do: body
  defp maybe_put_sha(body, sha), do: Map.put(body, :sha, sha)
end
