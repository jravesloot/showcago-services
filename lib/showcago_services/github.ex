defmodule ShowcagoServices.GitHub do
  @moduledoc """
  Lightweight HTTP client for the GitHub REST API using Req.
  Authenticates via a GitHub App installation token.
  """

  @base_url "https://api.github.com"

  @doc """
  Returns the configured `%{owner, repo, base_branch}` map.
  """
  def repo_config do
    Application.fetch_env!(:showcago_services, :github_repo)
  end

  @doc """
  Performs a GET request against the GitHub API.
  """
  def get(path, opts \\ []) do
    req(path, :get, opts)
  end

  @doc """
  Performs a POST request against the GitHub API.
  """
  def post(path, body, opts \\ []) do
    req(path, :post, Keyword.put(opts, :json, body))
  end

  @doc """
  Performs a PUT request against the GitHub API.
  """
  def put(path, body, opts \\ []) do
    req(path, :put, Keyword.put(opts, :json, body))
  end

  defp req(path, method, opts) do
    {:ok, token} = ShowcagoServices.GitHub.Auth.installation_token()

    base_opts = [
      url: @base_url <> path,
      method: method,
      headers: [
        {"authorization", "Bearer #{token}"},
        {"accept", "application/vnd.github+json"},
        {"x-github-api-version", "2022-11-28"}
      ]
    ]

    case Req.request(Keyword.merge(base_opts, opts)) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
