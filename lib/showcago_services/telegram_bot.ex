defmodule ShowcagoServices.TelegramBot do
  use Telegram.Bot

  alias ShowcagoServices.Shows
  alias ShowcagoServices.Users
  require Logger

  @chicago_time_zone "America/Chicago"
  @max_shows 10

  @impl Telegram.Bot
  def handle_update(
        %{
          "message" => %{
            "chat" => %{"id" => chat_id},
            "from" => %{"id" => telegram_id},
            "text" => text
          }
        },
        token
      )
      when is_integer(chat_id) and is_integer(telegram_id) and is_binary(text) do
    if Users.get_user_by_telegram_id(telegram_id) do
      Logger.info(
        "Received Telegram message: #{text} from telegram_id: #{telegram_id}, chat_id: #{chat_id}"
      )

      forward_message_to_agent(telegram_id, chat_id, text, token)

      # if upcoming_shows_request?(text) do
      #   send_upcoming_shows(chat_id, token)
      # end
    else
      Logger.warning("Ignoring Telegram message from unknown telegram_id: #{telegram_id}")
    end

    :ok
  end

  def handle_update(_update, _token), do: :ok

  defp forward_message_to_agent(telegram_id, chat_id, text, token) do
    agent_pid = case Jido.AgentServer.whereis(Jido.Registry, "shows_agent_#{telegram_id}") do
      nil ->
        Logger.info("Starting new ShowsAgent for telegram_id: #{telegram_id}") # probably should use chat_id
        {:ok, pid} = Jido.AgentServer.start_link(agent: ShowcagoServices.Jido.ShowsAgent, id: "shows_agent_#{telegram_id}")
        pid

      pid ->
        Logger.info("Found existing ShowsAgent for telegram_id: #{telegram_id}")
        pid
    end

    ShowcagoServices.Jido.ShowsAgent.handle_telegram_message(agent_pid, chat_id, text, token)
  end

  defp upcoming_shows_request?(text) do
    normalized_text =
      text
      |> String.downcase()
      |> String.trim()

    String.starts_with?(normalized_text, "/shows") or
      String.starts_with?(normalized_text, "/upcoming") or
      String.contains?(normalized_text, "upcoming shows")
  end

  defp send_upcoming_shows(chat_id, token) do
    message =
      Shows.list_upcoming_shows()
      |> Enum.take(@max_shows)
      |> format_upcoming_shows_response()

    Telegram.Api.request(token, "sendMessage",
      chat_id: chat_id,
      text: message,
      disable_web_page_preview: true
    )

    :ok
  end

  defp format_upcoming_shows_response([]) do
    "No upcoming shows found right now."
  end

  defp format_upcoming_shows_response(shows) do
    lines =
      Enum.map(shows, fn show ->
        title = show.notes || "Untitled event"
        venue_name = (show.venue && show.venue.name) || "Unknown venue"

        "• #{format_show_datetime(show.date)} — #{title} @ #{venue_name}"
      end)

    Enum.join(["Upcoming shows:", "" | lines], "\n")
  end

  defp format_show_datetime(%DateTime{} = datetime) do
    datetime
    |> chicago_datetime()
    |> Calendar.strftime("%a, %b %-d %I:%M %p CT")
  end

  defp chicago_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted_datetime} -> shifted_datetime
      _ -> datetime
    end
  end
end
