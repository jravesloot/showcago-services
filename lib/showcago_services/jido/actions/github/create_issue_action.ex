defmodule ShowcagoServices.Jido.Actions.GitHub.CreateIssueAction do
  use Jido.Action,
    name: "create_github_issue",
    description: "Creates a new issue in the GitHub repository.",
    schema: [
      title: [type: :string, required: true, doc: "The title of the issue"],
      body: [type: :string, required: true, doc: "The description body of the issue"],
      labels: [
        type: {:list, :string},
        required: false,
        default: [],
        doc: "Optional list of label names to apply to the issue"
      ]
    ]

  alias ShowcagoServices.GitHub

  @impl true
  def run(%{title: title, body: body} = params, _context) do
    %{owner: owner, repo: repo} = GitHub.repo_config()
    labels = Map.get(params, :labels, [])

    issue_body = %{title: title, body: body}
    issue_body = if labels != [], do: Map.put(issue_body, :labels, labels), else: issue_body

    case GitHub.post("/repos/#{owner}/#{repo}/issues", issue_body) do
      {:ok, %{"html_url" => url, "number" => number}} ->
        {:ok, %{url: url, number: number}}

      {:error, reason} ->
        {:error, "Failed to create issue: #{inspect(reason)}"}
    end
  end
end
