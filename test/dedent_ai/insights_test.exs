defmodule DedentAi.InsightsTest do
  use ExUnit.Case, async: true

  alias DedentAi.Insights

  test "extracts a single ★ Insight block" do
    text = """
    Some intro text.

      ★ Insight ─────────────────────────────────────
      Lighthouse lab tests have known variance.
      Trust field data over lab runs.
      ─────────────────────────────────────────────────

    Trailing paragraph.
    """

    assert Insights.extract(text) == [
             "Lighthouse lab tests have known variance.\nTrust field data over lab runs."
           ]
  end

  test "extracts multiple blocks in source order" do
    text = """
    ★ Insight ───
    First.
    ───

    ★ Insight ───
    Second.
    ───
    """

    assert Insights.extract(text) == ["First.", "Second."]
  end

  test "returns empty list when there are no insights" do
    assert Insights.extract("just prose, no callouts") == []
  end

  test "ignores stray rule lines outside an insight" do
    text = """
    ─────────────────────────────────────────────────

    No insight markers here.
    """

    assert Insights.extract(text) == []
  end

  test "preserves blank lines inside an insight" do
    text = """
    ★ Insight ───
    Top line.

    Bottom line.
    ───
    """

    assert Insights.extract(text) == ["Top line.\n\nBottom line."]
  end
end
