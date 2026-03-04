defmodule ShowcagoServices.Jido.Actions.GitHub.OpenPullRequestAction do
  use Jido.Action,
    name: "open_github_pull_request",
    description: "Opens a pull request in the GitHub repository.",
    schema: [
      title: [type: :string, required: true, doc: "The title of the pull request"],
      body: [type: :string, required: true, doc: "The description body of the pull request"],
      head: [type: :string, required: true, doc: "The branch containing the changes"]
    ]

  alias ShowcagoServices.GitHub

  @impl true
  def run(%{title: title, body: body, head: head}, _context) do
    %{owner: owner, repo: repo, base_branch: base_branch} = GitHub.repo_config()

    case GitHub.post("/repos/#{owner}/#{repo}/pulls", %{
           title: title,
           body: body,
           head: head,
           base: base_branch
         }) do
      {:ok, %{"html_url" => url, "number" => number}} ->
        {:ok, %{url: url, number: number}}

      {:error, reason} ->
        {:error, "Failed to open pull request: #{inspect(reason)}"}
    end
  end
end
