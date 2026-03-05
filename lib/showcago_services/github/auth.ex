defmodule ShowcagoServices.GitHub.Auth do
  @moduledoc """
  Handles GitHub App authentication: JWT generation and installation
  access token management with automatic caching and refresh.
  """

  @token_refresh_buffer_seconds 300

  @doc """
  Returns a valid installation access token, refreshing if needed.
  Tokens are cached in `:persistent_term` and refreshed 5 minutes
  before expiry.
  """
  def installation_token do
    case cached_token() do
      {:ok, token} -> {:ok, token}
      :expired -> refresh_token()
    end
  end

  defp cached_token do
    case :persistent_term.get(:github_installation_token, nil) do
      nil ->
        :expired

      {token, expires_at} ->
        if DateTime.before?(DateTime.utc_now(), expires_at) do
          {:ok, token}
        else
          :expired
        end
    end
  end

  defp refresh_token do
    jwt = generate_jwt()
    installation_id = Application.fetch_env!(:showcago_services, :github_app_installation_id)

    case Req.post(
           url: "https://api.github.com/app/installations/#{installation_id}/access_tokens",
           headers: [
             {"authorization", "Bearer #{jwt}"},
             {"accept", "application/vnd.github+json"},
             {"x-github-api-version", "2022-11-28"}
           ]
         ) do
      {:ok, %Req.Response{status: 201, body: %{"token" => token, "expires_at" => expires_at_str}}} ->
        {:ok, expires_at, _} = DateTime.from_iso8601(expires_at_str)
        buffered_expiry = DateTime.add(expires_at, -@token_refresh_buffer_seconds, :second)
        :persistent_term.put(:github_installation_token, {token, buffered_expiry})
        {:ok, token}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_jwt do
    app_id = Application.fetch_env!(:showcago_services, :github_app_id)
    private_key_pem = Application.fetch_env!(:showcago_services, :github_app_private_key)

    now = System.system_time(:second)

    header = %{"alg" => "RS256", "typ" => "JWT"}
    payload = %{"iss" => app_id, "iat" => now - 60, "exp" => now + 600}

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(payload), padding: false)
    signing_input = "#{header_b64}.#{payload_b64}"

    [pem_entry] = :public_key.pem_decode(private_key_pem)
    private_key = :public_key.pem_entry_decode(pem_entry)

    signature = :public_key.sign(signing_input, :sha256, private_key)
    signature_b64 = Base.url_encode64(signature, padding: false)

    "#{signing_input}.#{signature_b64}"
  end
end
