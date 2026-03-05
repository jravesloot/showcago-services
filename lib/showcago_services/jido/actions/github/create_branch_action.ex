defmodule ShowcagoServices.Jido.Actions.GitHub.CreateBranchAction do
  @moduledoc false
  use Jido.Action,
    name: "create_github_branch",
    description: "Creates a new branch in the GitHub repository from the base branch.",
    schema: [
      branch_name: [
        type: :string,
        required: true,
        doc: "The name of the new branch to create"
      ]
    ]

  alias ShowcagoServices.GitHub

  @impl true
  def run(%{branch_name: branch_name}, _context) do
    %{owner: owner, repo: repo, base_branch: base_branch} = GitHub.repo_config()

    with {:ok, %{"object" => %{"sha" => sha}}} <-
           GitHub.get("/repos/#{owner}/#{repo}/git/ref/heads/#{base_branch}"),
         {:ok, _ref} <-
           GitHub.post("/repos/#{owner}/#{repo}/git/refs", %{
             ref: "refs/heads/#{branch_name}",
             sha: sha
           }) do
      {:ok, %{branch_name: branch_name, base_sha: sha}}
    else
      {:error, reason} ->
        {:error, "Failed to create branch #{branch_name}: #{inspect(reason)}"}
    end
  end
end
