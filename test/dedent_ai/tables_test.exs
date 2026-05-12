defmodule DedentAi.TablesTest do
  use ExUnit.Case, async: true

  alias DedentAi.Tables

  test "converts a two-column table with header separator" do
    input = """
    ┌──────────────┬───────────────┐
    │     Check    │     Result    │
    ├──────────────┼───────────────┤
    │ Title fix    │ Done          │
    └──────────────┴───────────────┘
    """

    output = Tables.transform(input)

    assert output =~ "| Check | Result |"
    assert output =~ "| --- | --- |"
    assert output =~ "| Title fix | Done |"
    refute output =~ "┌"
    refute output =~ "│"
  end

  test "handles per-row separators between every body row" do
    input = """
    ┌────┬────┐
    │ H1 │ H2 │
    ├────┼────┤
    │ A  │ B  │
    ├────┼────┤
    │ C  │ D  │
    └────┴────┘
    """

    output = Tables.transform(input)

    assert output =~ "| H1 | H2 |"
    assert output =~ "| A | B |"
    assert output =~ "| C | D |"
  end

  test "preserves prose surrounding the table" do
    input = """
    Before the table.

    ┌────┬────┐
    │ H1 │ H2 │
    ├────┼────┤
    │ A  │ B  │
    └────┴────┘

    After the table.
    """

    output = Tables.transform(input)

    assert output =~ "Before the table."
    assert output =~ "After the table."
    assert output =~ "| H1 | H2 |"
  end

  test "transforms multiple tables in one input" do
    input = """
    ┌────┐
    │ T1 │
    └────┘

    Middle text.

    ┌────┐
    │ T2 │
    └────┘
    """

    output = Tables.transform(input)

    assert output =~ "| T1 |"
    assert output =~ "| T2 |"
    assert output =~ "Middle text."
  end

  test "leaves a malformed table (no bottom) untouched" do
    input = """
    ┌──────┬──────┐
    │ no   │ bot  │
    next line is prose.
    """

    output = Tables.transform(input)

    assert output =~ "┌──────┬──────┐"
    assert output =~ "│ no   │ bot  │"
    assert output =~ "next line is prose."
  end

  test "escapes pipe characters in cell content" do
    input = """
    ┌──────────┐
    │ a|b      │
    └──────────┘
    """

    output = Tables.transform(input)

    assert output =~ "a\\|b"
    refute output =~ ~r/\| a\|b \|/
  end

  test "preserves emoji and unicode in cells" do
    input = """
    ┌──────────────┬───────────────┐
    │ Step         │ Status        │
    ├──────────────┼───────────────┤
    │ Deploy live  │ ✅ Done       │
    └──────────────┴───────────────┘
    """

    output = Tables.transform(input)

    assert output =~ "| Deploy live | ✅ Done |"
  end

  test "leaves text without tables completely untouched" do
    input = "Plain prose.\n\nA list:\n- one\n- two\n"
    assert Tables.transform(input) == input
  end

  test "handles indented tables (after a paragraph that hasn't been dedented yet)" do
    input = """
      ┌────┬────┐
      │ H1 │ H2 │
      ├────┼────┤
      │ A  │ B  │
      └────┴────┘
    """

    output = Tables.transform(input)

    assert output =~ "| H1 | H2 |"
    assert output =~ "| A | B |"
  end
end
