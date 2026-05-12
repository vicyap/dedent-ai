defmodule DedentAi.TextTest do
  use ExUnit.Case, async: true

  alias DedentAi.Text

  test "dedents common indentation without terminal markers" do
    input = "    alpha\n      beta\n    gamma\n"

    assert Text.clean(input) == "alpha\n  beta\ngamma\n"
  end

  test "strips a Claude terminal marker and dedents continuation lines" do
    input = "● Got enough to draft\n  r/GLP1 reader profile\n  - Wrong voice\n"

    assert Text.clean(input) == "Got enough to draft\nr/GLP1 reader profile\n- Wrong voice\n"
  end

  test "strips a Codex terminal marker and preserves blank lines" do
    input = "• r/GLP1\n\n  Title: sema vs tirz\n  trying to sanity-check this"

    assert Text.clean(input) == "r/GLP1\n\nTitle: sema vs tirz\ntrying to sanity-check this"
  end

  test "normalizes whitespace-only blank lines during dedent_ai" do
    input = "  one\n    \n  two"

    assert Text.clean(input) == "one\n\ntwo"
  end

  test "repairs wrapped prose without changing strict mode" do
    input =
      "Scan my Claude Code prompt history for cases where I described a well-known\nsoftware-engineering or business concept in long-form words.\nSteps:\n1. Build the JSONL file. Schema of each line is\n   display and metadata\n   - Strip pasted placeholders\n   - Keep long prompts\n2. Split into chunks.\n   Round-robin keeps each chunk spread across the full range."

    assert Text.clean(input, smart: false) == input

    assert Text.clean(input) ==
             "Scan my Claude Code prompt history for cases where I described a well-known software-engineering or business concept in long-form words.\n\nSteps:\n\n1. Build the JSONL file. Schema of each line is display and metadata\n   - Strip pasted placeholders\n   - Keep long prompts\n\n2. Split into chunks. Round-robin keeps each chunk spread across the full range."
  end

  test "repairs wrapped blockquotes and keeps quoted blank lines" do
    input =
      "> Read /tmp/reverse-dict/cN.jsonl.\n> Find moments where the user described one of these\n> concepts in plain words.\n>\n> Systems / eng: pubsub,\n> idempotency, fan-out."

    assert Text.clean(input) ==
             "> Read /tmp/reverse-dict/cN.jsonl. Find moments where the user described one of these concepts in plain words.\n>\n> Systems / eng: pubsub, idempotency, fan-out."
  end

  test "does not repair wrapped lines inside fenced code" do
    input =
      "Before the block\n```sh\njq -r --arg q \"<quote>\"\n'select(.display | contains($q))'\n```\nAfter the block"

    assert Text.clean(input) == input
  end

  test "preserves already spaced markdown prompts" do
    input =
      "Scan my prompt history.\n\nSteps:\n\n1. Build /tmp/reverse-dict/typed_prompts.jsonl from history.\n   - Strip pasted placeholders\n   - Keep long prompts\n\n2. Split into chunks.\n\n   > Read /tmp/reverse-dict/cN.jsonl.\n   >\n   > Return ONLY a JSON array.\n\n3. Output the final markdown report:\n\n   # Reverse Jargon\n\n   ## term\n\n   > verbatim quote"

    assert Text.clean(input) == input
  end
end
