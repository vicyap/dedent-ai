defmodule DedentAiWeb.DedentLiveTest do
  use DedentAiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the dedent-ai tool", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "dedent-ai"
    assert html =~ "Paste terminal output"
  end

  test "updates output as input changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent_ai-form", dedent_ai: %{input: "• r/GLP1\n\n  Title: small GLP cut"})
    |> render_change()

    html =
      view
      |> element("#dedent_ai-output-text")
      |> render()

    assert html =~ "r/GLP1"
    assert html =~ "Title: small GLP cut"
    refute html =~ "• r/GLP1"
  end

  test "repairs wrapped markdown prompts automatically", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent_ai-form",
      dedent_ai: %{
        input:
          "Scan my Claude Code prompt history for cases where I described a well-known\nsoftware-engineering concept in long-form words.\nSteps:\n1. Build the file.\n   Keep the records spread across the full time range.\n2. Return markdown."
      }
    )
    |> render_change()

    html =
      view
      |> element("#dedent_ai-output-text")
      |> render()

    assert html =~
             "Scan my Claude Code prompt history for cases where I described a well-known software-engineering concept in long-form words."

    assert html =~ "Steps:\n\n1. Build the file."
    assert html =~ "2. Return markdown."
  end

  test "clears input and output", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent_ai-form", dedent_ai: %{input: "  alpha"})
    |> render_change()

    assert render(view) =~ "alpha"

    view
    |> element("button", "Clear")
    |> render_click()

    refute render(view) =~ "alpha"
  end

  test "extracts insights and shows the panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    input = """
    ● Headline.

      ★ Insight ─────────────────────────────────────
      Lighthouse lab tests have known variance.
      Trust field data over lab runs.
      ─────────────────────────────────────────────────

    Followup paragraph.
    """

    view
    |> form("#dedent_ai-form", dedent_ai: %{input: input})
    |> render_change()

    html = render(view)
    assert html =~ "Insights"
    assert html =~ "Lighthouse lab tests have known variance."
    assert html =~ "Trust field data over lab runs."
  end

  test "preview tab renders markdown output as HTML", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#dedent_ai-form",
      dedent_ai: %{input: "## Header\n\n- one\n- two\n\n**bold** text"}
    )
    |> render_change()

    view
    |> element("button[phx-value-view=preview]")
    |> render_click()

    html = element(view, "#dedent_ai-output-html") |> render()
    assert html =~ "<h2>"
    assert html =~ "Header"
    assert html =~ "<strong>bold</strong>"
  end
end
