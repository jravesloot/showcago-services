defmodule ShowcagoServices.Jido.ShowsAgent do
  use Jido.AI.Agent,
    name: "shows_agent",
    description: "An agent that provides information about upcoming shows in Chicago, including details like date, venue, and artists.",
    model: :fast,
    tools: [
      ShowcagoServices.Jido.Actions.ListShowsAction
    ],
    system_prompt: """
    You are a helpful assistant that provides information about upcoming shows
    in Chicago. You have access to a tool that can list upcoming shows with
    details like date, venue, and artists. When a user asks about upcoming
    shows, use the tool to get the latest information and share it in a clear
    and concise way.
    """
end
