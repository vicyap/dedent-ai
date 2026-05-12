defmodule DedentAiWeb.DedentLive do
  use DedentAiWeb, :live_view

  alias DedentAi.{Insights, Text}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:output_view, :raw)
     |> assign_text("")}
  end

  @impl true
  def handle_event("update", %{"dedent_ai" => params}, socket) when is_map(params) do
    input = Map.get(params, "input", "")
    {:noreply, assign_text(socket, input)}
  end

  def handle_event("update", _params, socket) do
    {:noreply, assign_text(socket, "")}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, assign_text(socket, "")}
  end

  def handle_event("set_view", %{"view" => view}, socket) when view in ~w(raw preview) do
    {:noreply, assign(socket, :output_view, String.to_existing_atom(view))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-base-100">
      <Layouts.flash_group flash={@flash} />

      <div class="mx-auto flex min-h-screen w-full max-w-7xl flex-col px-4 py-4 sm:px-6 lg:px-8">
        <header class="flex min-h-14 items-center justify-between gap-4 border-b border-base-300">
          <div class="flex min-w-0 items-center gap-3">
            <div class="flex size-9 shrink-0 items-center justify-center rounded-box bg-base-200 text-base-content">
              <.icon name="hero-bars-3-bottom-left" class="size-5" />
            </div>
            <div class="min-w-0">
              <h1 class="truncate text-lg font-semibold leading-6">dedent-ai</h1>
              <div class="mt-1 flex items-center gap-2">
                <span class="badge badge-soft badge-primary badge-sm">smart</span>
                <span class="badge badge-soft badge-neutral badge-sm">{@input_lines} lines</span>
                <span :if={@insights != []} class="badge badge-soft badge-accent badge-sm">
                  {length(@insights)} insight{if length(@insights) == 1, do: "", else: "s"}
                </span>
              </div>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="clear"
              disabled={@input == ""}
            >
              <.icon name="hero-trash" class="size-4" /> Clear
            </button>
            <Layouts.theme_toggle />
          </div>
        </header>

        <section class="grid flex-1 grid-cols-1 gap-4 py-4 lg:grid-cols-2">
          <.form
            for={@form}
            id="dedent_ai-form"
            phx-change="update"
            phx-submit="update"
            class="flex min-h-[28rem] flex-col rounded-box border border-base-300 bg-base-100"
          >
            <div class="flex h-12 items-center justify-between gap-3 border-b border-base-300 px-4">
              <label for={@form[:input].id} class="text-sm font-medium">Input</label>
              <span class="text-xs tabular-nums text-base-content/60">{@input_chars} chars</span>
            </div>
            <textarea
              id={@form[:input].id}
              name={@form[:input].name}
              class="textarea textarea-ghost min-h-[28rem] flex-1 resize-none rounded-none border-0 font-mono text-sm leading-6 focus:outline-none"
              placeholder="Paste terminal output"
              phx-debounce="120"
              autofocus
            >{@input}</textarea>
          </.form>

          <section class="flex min-h-[28rem] flex-col rounded-box border border-base-300 bg-base-100">
            <div class="flex h-12 items-center justify-between gap-3 border-b border-base-300 px-4">
              <div class="flex items-center gap-3">
                <div role="tablist" class="tabs tabs-sm tabs-boxed bg-base-200">
                  <button
                    type="button"
                    role="tab"
                    class={["tab", @output_view == :raw && "tab-active"]}
                    phx-click="set_view"
                    phx-value-view="raw"
                  >
                    Raw
                  </button>
                  <button
                    type="button"
                    role="tab"
                    class={["tab", @output_view == :preview && "tab-active"]}
                    phx-click="set_view"
                    phx-value-view="preview"
                    disabled={not @markdown?}
                    title={not @markdown? && "No markdown detected"}
                  >
                    Preview
                  </button>
                </div>
                <span class="text-xs tabular-nums text-base-content/60">{@output_chars} chars</span>
              </div>

              <div class="flex items-center gap-2">
                <button
                  id="copy-output"
                  type="button"
                  class="btn btn-ghost btn-sm"
                  phx-hook="CopyToClipboard"
                  data-clipboard-target="#dedent_ai-output-text"
                  disabled={@output == ""}
                >
                  <.icon name="hero-clipboard-document" class="size-4" /> Copy
                </button>
                <button
                  id="copy-rich"
                  type="button"
                  class="btn btn-primary btn-sm"
                  phx-hook="CopyRich"
                  data-text-target="#dedent_ai-output-text"
                  data-html-target="#dedent_ai-output-html"
                  disabled={@output == "" or not @markdown?}
                  title={not @markdown? && "Renders as rich text in Gmail, Notion, Docs"}
                >
                  <.icon name="hero-clipboard-document-check" class="size-4" /> Copy formatted
                </button>
              </div>
            </div>

            <textarea
              id="dedent_ai-output-text"
              class={[
                "textarea textarea-ghost min-h-[28rem] flex-1 resize-none rounded-none border-0 font-mono text-sm leading-6 focus:outline-none",
                @output_view == :preview && "hidden"
              ]}
              readonly
            >{@output}</textarea>

            <div
              id="dedent_ai-output-html"
              class={[
                "prose prose-sm max-w-none flex-1 overflow-auto px-4 py-3 text-sm leading-6",
                @output_view == :raw && "hidden"
              ]}
            >
              {Phoenix.HTML.raw(@output_html)}
            </div>
          </section>
        </section>

        <section :if={@insights != []} class="pb-4">
          <div class="rounded-box border border-base-300 bg-base-100">
            <div class="flex h-12 items-center justify-between gap-3 border-b border-base-300 px-4">
              <div class="flex items-center gap-2 text-sm font-medium">
                <.icon name="hero-sparkles" class="size-4 text-accent" /> Insights
              </div>
              <span class="text-xs tabular-nums text-base-content/60">
                {length(@insights)} extracted
              </span>
            </div>
            <ul class="divide-y divide-base-300">
              <li :for={{insight, idx} <- Enum.with_index(@insights)} class="flex gap-3 px-4 py-3">
                <span class="mt-0.5 inline-flex size-6 shrink-0 items-center justify-center rounded-full bg-accent/10 text-xs font-semibold text-accent">
                  {idx + 1}
                </span>
                <p class="whitespace-pre-wrap text-sm leading-6">{insight}</p>
                <button
                  id={"copy-insight-#{idx}"}
                  type="button"
                  class="btn btn-ghost btn-xs ml-auto self-start"
                  phx-hook="CopyText"
                  data-copy-text={insight}
                >
                  <.icon name="hero-clipboard-document" class="size-3" /> Copy
                </button>
              </li>
            </ul>
          </div>
        </section>
      </div>
    </main>
    """
  end

  defp assign_text(socket, input) do
    output = Text.clean(input)
    markdown? = Text.looks_like_markdown?(output)
    insights = Insights.extract(input)

    output_view =
      if not markdown? and socket.assigns[:output_view] == :preview,
        do: :raw,
        else: socket.assigns[:output_view] || :raw

    assign(socket,
      form: to_form(%{"input" => input}, as: :dedent_ai),
      input: input,
      output: output,
      output_html: if(markdown?, do: Text.to_html(output), else: ""),
      markdown?: markdown?,
      insights: insights,
      input_chars: String.length(input),
      output_chars: String.length(output),
      input_lines: line_count(input),
      output_view: output_view
    )
  end

  defp line_count(""), do: 0
  defp line_count(text), do: text |> String.split("\n", trim: false) |> length()
end
