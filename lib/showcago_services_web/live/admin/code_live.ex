defmodule ShowcagoServicesWeb.Admin.CodeLive do
  @moduledoc false
  use ShowcagoServicesWeb, :live_view

  alias ShowcagoServices.CodeTasks

  @chicago_time_zone "America/Chicago"

  def mount(_params, _session, socket) do
    if connected?(socket), do: CodeTasks.subscribe()

    tasks = CodeTasks.list_tasks()

    {:ok,
     socket
     |> assign(:page_title, "Code Agent")
     |> assign(:prompt, "")
     |> assign(:submitting, false)
     |> stream(:tasks, tasks)}
  end

  def handle_event("update-prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :prompt, prompt)}
  end

  def handle_event("submit-prompt", %{"prompt" => prompt}, socket) do
    prompt = String.trim(prompt)

    if prompt == "" do
      {:noreply, put_flash(socket, :error, "Prompt cannot be empty")}
    else
      {:ok, task} = CodeTasks.submit_task(prompt)

      {:noreply,
       socket
       |> assign(:prompt, "")
       |> assign(:submitting, false)
       |> stream_insert(:tasks, task, at: 0)}
    end
  end

  def handle_info({:task_submitted, _task}, socket) do
    {:noreply, socket}
  end

  def handle_info({:task_updated, task}, socket) do
    {:noreply, stream_insert(socket, :tasks, task)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]} full_width={true}>
      <ShowcagoServicesWeb.AdminComponents.admin_layout active_page={:code}>
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900">Code Agent</h1>
          <p class="mt-2 text-sm text-gray-600">
            Prompt the CodeAgent to create GitHub issues or open PRs with changes.
          </p>
        </div>

        <%!-- Prompt form --%>
        <div class="mb-8 rounded-lg border border-slate-200 bg-white p-5 shadow-sm">
          <form id="code-prompt-form" phx-submit="submit-prompt" class="space-y-4">
            <div>
              <label for="code-prompt-input" class="block text-sm font-medium text-slate-700 mb-1">
                Prompt
              </label>
              <textarea
                id="code-prompt-input"
                name="prompt"
                rows="4"
                placeholder="Describe the task for the CodeAgent..."
                class="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder-slate-400 shadow-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500 focus:outline-none"
                phx-change="update-prompt"
                value={@prompt}
              >{@prompt}</textarea>
            </div>
            <div class="flex justify-end">
              <button
                id="submit-code-prompt"
                type="submit"
                disabled={@submitting}
                class={[
                  "inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium text-white shadow-sm transition",
                  if(@submitting,
                    do: "bg-blue-400 cursor-not-allowed",
                    else: "bg-blue-600 hover:bg-blue-700 active:bg-blue-800"
                  )
                ]}
              >
                <.icon name="hero-paper-airplane" class="size-4" />
                {if(@submitting, do: "Submitting…", else: "Submit")}
              </button>
            </div>
          </form>
        </div>

        <%!-- Task history --%>
        <div class="rounded-lg border border-slate-200 bg-white shadow-sm">
          <div class="border-b border-slate-200 px-5 py-3">
            <h2 class="text-lg font-semibold text-slate-900">Task History</h2>
          </div>

          <div id="code-tasks" phx-update="stream" class="divide-y divide-slate-100">
            <div class="hidden only:block px-5 py-8 text-center text-sm text-slate-500">
              No tasks yet. Submit a prompt above to get started.
            </div>

            <div :for={{dom_id, task} <- @streams.tasks} id={dom_id} class="px-5 py-4">
              <div class="flex items-start justify-between gap-4">
                <div class="min-w-0 flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <.status_badge status={task.status} />
                    <span class="text-xs text-slate-500">
                      {format_chicago_datetime(task.submitted_at)}
                    </span>
                    <span :if={task.completed_at} class="text-xs text-slate-400">
                      — completed {format_chicago_datetime(task.completed_at)}
                    </span>
                  </div>
                  <p class="text-sm font-medium text-slate-900 whitespace-pre-wrap break-words">
                    {task.prompt}
                  </p>
                </div>
              </div>

              <div
                :if={task.status == :completed && task.response}
                class="mt-3 rounded-lg bg-green-50 border border-green-200 p-3"
              >
                <p class="text-xs font-medium text-green-800 mb-1">Response</p>
                <pre class="text-sm text-green-900 whitespace-pre-wrap break-words">{task.response}</pre>
              </div>

              <div
                :if={task.status == :failed && task.error}
                class="mt-3 rounded-lg bg-red-50 border border-red-200 p-3"
              >
                <p class="text-xs font-medium text-red-800 mb-1">Error</p>
                <pre class="text-sm text-red-900 whitespace-pre-wrap break-words">{task.error}</pre>
              </div>
            </div>
          </div>
        </div>
      </ShowcagoServicesWeb.AdminComponents.admin_layout>
    </Layouts.app>
    """
  end

  defp status_badge(%{status: :pending} = assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-700">
      Pending
    </span>
    """
  end

  defp status_badge(%{status: :running} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-medium text-amber-800">
      <.icon name="hero-arrow-path" class="size-3 animate-spin" /> Running
    </span>
    """
  end

  defp status_badge(%{status: :completed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
      <.icon name="hero-check" class="size-3" /> Completed
    </span>
    """
  end

  defp status_badge(%{status: :failed} = assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 rounded-full bg-red-100 px-2.5 py-0.5 text-xs font-medium text-red-800">
      <.icon name="hero-x-mark" class="size-3" /> Failed
    </span>
    """
  end

  defp format_chicago_datetime(%DateTime{} = datetime) do
    case DateTime.shift_zone(datetime, @chicago_time_zone) do
      {:ok, shifted} -> Calendar.strftime(shifted, "%b %-d, %I:%M %p CT")
      _ -> Calendar.strftime(datetime, "%b %-d, %I:%M %p UTC")
    end
  end
end
