defmodule DedentAi.Text do
  @moduledoc """
  Text cleanup for pasted terminal output.
  """

  @terminal_markers ["●", "•"]

  @doc """
  Removes a leading terminal marker from the first content line and dedents the text.
  """
  @spec clean(binary()) :: binary()
  def clean(text), do: clean(text, smart: true)

  @doc """
  Renders `text` (treated as Markdown) to an HTML string. Lines that look like
  ASCII drawings (box-drawing chars, `★ Insight ───` rules) get wrapped in
  fenced code blocks so they preview without mangling.
  """
  @spec to_html(binary()) :: binary()
  def to_html(text) when is_binary(text) do
    case Earmark.as_html(text, escape: true, smartypants: false, compact_output: false) do
      {:ok, html, _} -> html
      {:error, html, _} -> html
    end
  end

  @doc """
  Returns true if `text` shows signs of Markdown formatting that meaningfully
  benefit from preview/rich copy. Plain prose returns false.
  """
  @spec looks_like_markdown?(binary()) :: boolean()
  def looks_like_markdown?(text) when is_binary(text) do
    String.match?(text, ~r/(^|\n)\s*(\#{1,6}\s|[-*+]\s|\d+[.)]\s|>\s|```|~~~|★\s*Insight)/u) or
      String.match?(text, ~r/\*\*[^*\n]+\*\*|`[^`\n]+`|\[[^\]\n]+\]\([^)\n]+\)/u)
  end

  @doc """
  Cleans terminal text with optional wrapped-line repair.

  Options:

    * `:smart` / `:repair_wraps` — reflow wrapped Markdown lines (default true)
    * `:filter_status` — drop Claude Code status lines like `✻ Sautéed for 13s…`
      or `✻ Claude resuming…` and collapse the gap they leave behind
      (default true)
  """
  @spec clean(binary(), keyword()) :: binary()
  def clean(text, opts) when is_binary(text) and is_list(opts) do
    text = if Keyword.get(opts, :filter_status, true), do: filter_status_lines(text), else: text
    lines = split_lines(text)
    {lines, marker_lines} = strip_paragraph_terminal_markers(lines)
    indent_width = common_indent_width(lines, marker_lines)

    cleaned =
      lines
      |> Enum.map(&drop_indent(&1, indent_width))
      |> Enum.join("\n")

    if Keyword.get(opts, :smart, Keyword.get(opts, :repair_wraps, false)) do
      smart_cleanup(cleaned)
    else
      cleaned
    end
  end

  defp split_lines(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.split("\n", trim: false)
  end

  defp filter_status_lines(text) do
    text
    |> split_lines()
    |> Enum.reject(&status_line?/1)
    |> collapse_blanks([])
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp status_line?(line), do: String.match?(line, ~r/^\s*✻\s/u)

  defp collapse_blanks([], acc), do: acc

  defp collapse_blanks([line | rest], [prev | _] = acc) do
    if blank?(line) and blank?(prev) do
      collapse_blanks(rest, acc)
    else
      collapse_blanks(rest, [line | acc])
    end
  end

  defp collapse_blanks([line | rest], []), do: collapse_blanks(rest, [line])

  defp strip_paragraph_terminal_markers(lines) do
    {reversed, markers, _state} =
      lines
      |> Enum.with_index()
      |> Enum.reduce({[], MapSet.new(), :paragraph_start}, fn
        {line, _idx}, {acc, markers, _state} when line == "" ->
          {[line | acc], markers, :paragraph_start}

        {line, idx}, {acc, markers, :paragraph_start} ->
          if blank?(line) do
            {[line | acc], markers, :paragraph_start}
          else
            {stripped, stripped?} = strip_terminal_marker(line)
            markers = if stripped?, do: MapSet.put(markers, idx), else: markers
            {[stripped | acc], markers, :inside}
          end

        {line, _idx}, {acc, markers, :inside} ->
          if blank?(line) do
            {[line | acc], markers, :paragraph_start}
          else
            {[line | acc], markers, :inside}
          end
      end)

    {Enum.reverse(reversed), markers}
  end

  defp strip_terminal_marker(line) do
    {indent, rest} = split_indent(line)

    case rest do
      <<marker::binary-size(3), rest::binary>> when marker in @terminal_markers ->
        {indent <> trim_marker_gap(rest), true}

      _ ->
        {line, false}
    end
  end

  defp split_indent(line), do: split_indent(line, "")

  defp split_indent(<<" ", rest::binary>>, indent), do: split_indent(rest, indent <> " ")
  defp split_indent(<<"\t", rest::binary>>, indent), do: split_indent(rest, indent <> "\t")
  defp split_indent(rest, indent), do: {indent, rest}

  defp trim_marker_gap(<<" ", rest::binary>>), do: trim_marker_gap(rest)
  defp trim_marker_gap(<<"\t", rest::binary>>), do: trim_marker_gap(rest)
  defp trim_marker_gap(rest), do: rest

  defp common_indent_width(lines, marker_lines) do
    lines
    |> Enum.with_index()
    |> Enum.reject(fn {line, index} -> blank?(line) or MapSet.member?(marker_lines, index) end)
    |> Enum.map(fn {line, _index} -> leading_indent_width(line) end)
    |> minimum_indent_width()
  end

  defp minimum_indent_width([]), do: 0
  defp minimum_indent_width(widths), do: Enum.min(widths)

  defp leading_indent_width(<<" ", rest::binary>>), do: 1 + leading_indent_width(rest)
  defp leading_indent_width(<<"\t", rest::binary>>), do: 1 + leading_indent_width(rest)
  defp leading_indent_width(_line), do: 0

  defp drop_indent(line, _width) when line == "", do: ""
  defp drop_indent(line, _width) when line in [" ", "\t"], do: ""
  defp drop_indent(line, width) when width <= 0, do: normalize_blank_line(line)
  defp drop_indent(<<" ", rest::binary>>, width), do: drop_indent(rest, width - 1)
  defp drop_indent(<<"\t", rest::binary>>, width), do: drop_indent(rest, width - 1)
  defp drop_indent(line, _width), do: normalize_blank_line(line)

  defp normalize_blank_line(line) do
    if blank?(line), do: "", else: line
  end

  defp blank?(line), do: String.trim(line) == ""

  defp smart_cleanup(text) do
    text
    |> split_lines()
    |> reflow_lines()
    |> space_markdown_blocks()
    |> Enum.join("\n")
  end

  defp reflow_lines(lines), do: reflow_lines(lines, false)

  defp reflow_lines(lines, force_wrap?), do: reflow_lines(lines, [], nil, false, force_wrap?)

  defp reflow_lines([], output, current, _in_fence?, _force_wrap?) do
    output
    |> flush_current(current)
    |> Enum.reverse()
  end

  defp reflow_lines([line | rest], output, current, in_fence?, force_wrap?) do
    cond do
      fence_line?(line) ->
        output
        |> flush_current(current)
        |> then(&reflow_lines(rest, [line | &1], nil, not in_fence?, force_wrap?))

      in_fence? ->
        reflow_lines(rest, [line | flush_current(output, current)], nil, in_fence?, force_wrap?)

      blank?(line) ->
        output
        |> flush_current(current)
        |> then(&reflow_lines(rest, ["" | &1], nil, in_fence?, force_wrap?))

      quote_line?(line) ->
        {quote_lines, rest} = Enum.split_while([line | rest], &quote_line?/1)
        quote_prefix = quote_prefix(List.first(quote_lines))

        quote_output =
          quote_lines
          |> Enum.map(&unquote_line/1)
          |> reflow_lines(true)
          |> Enum.map(&requote_line(&1, quote_prefix))
          |> Enum.reverse()

        output
        |> flush_current(current)
        |> then(&reflow_lines(rest, quote_output ++ &1, nil, in_fence?, force_wrap?))

      starts_structural_line?(line) ->
        output
        |> flush_current(current)
        |> then(&reflow_lines(rest, &1, line, in_fence?, force_wrap?))

      joinable?(current, line, force_wrap?) ->
        reflow_lines(rest, output, current <> " " <> String.trim(line), in_fence?, force_wrap?)

      true ->
        output
        |> flush_current(current)
        |> then(&reflow_lines(rest, &1, line, in_fence?, force_wrap?))
    end
  end

  defp flush_current(output, nil), do: output
  defp flush_current(output, current), do: [current | output]

  defp joinable?(nil, _line, _force_wrap?), do: false

  defp joinable?(current, line, force_wrap?) do
    not ends_with_hard_break?(current) and not starts_structural_line?(line) and
      (force_wrap? or wrap_candidate?(current, line))
  end

  defp wrap_candidate?(current, line) do
    String.length(String.trim_trailing(current)) >= 72 or list_continuation?(current, line)
  end

  defp list_continuation?(current, line) do
    starts_list_item?(current) and indented?(line) and not starts_structural_line?(line)
  end

  defp ends_with_hard_break?(line) do
    trimmed = String.trim(line)

    String.ends_with?(trimmed, ["```", "~~~"]) or label_line?(trimmed)
  end

  defp fence_line?(line), do: String.match?(line, ~r/^\s*(```|~~~)/)

  defp quote_line?(line), do: String.match?(line, ~r/^\s*>/)

  defp quote_prefix(line) do
    case Regex.run(~r/^(\s*>\s?)/, line) do
      [_, prefix] -> prefix
      _ -> "> "
    end
  end

  defp unquote_line(line) do
    String.replace(line, ~r/^\s*>\s?/, "")
  end

  defp requote_line("", prefix), do: String.trim_trailing(prefix)

  defp requote_line(line, prefix) do
    separator = if String.ends_with?(prefix, " "), do: "", else: " "

    prefix <> separator <> line
  end

  defp starts_structural_line?(line) do
    line = String.trim_leading(line)

    String.match?(line, ~r/^[#]{1,6}\s/) or
      starts_list_item?(line) or
      String.match?(line, ~r/^(```|~~~)/) or
      label_line?(line)
  end

  defp starts_list_item?(line),
    do: String.match?(String.trim_leading(line), ~r/^([-*+]|\d+[.)])\s+/)

  defp label_line?(line), do: String.ends_with?(line, ":") and String.length(line) <= 80

  defp indented?(<<" ", _rest::binary>>), do: true
  defp indented?(<<"\t", _rest::binary>>), do: true
  defp indented?(_line), do: false

  defp space_markdown_blocks(lines), do: space_markdown_blocks(lines, [])

  defp space_markdown_blocks([], output), do: Enum.reverse(output)

  defp space_markdown_blocks([line | rest], []), do: space_markdown_blocks(rest, [line])

  defp space_markdown_blocks([line | rest], [previous | _] = output) do
    output =
      if needs_blank_between?(previous, line) do
        [line, "" | output]
      else
        [line | output]
      end

    space_markdown_blocks(rest, output)
  end

  defp needs_blank_between?(previous, current) do
    not blank?(previous) and not blank?(current) and
      (top_level_numbered_item?(current) or
         separated_label?(current) or
         starts_heading?(current) or
         ends_heading?(previous) or
         quote_boundary?(previous, current) or
         code_line_boundary?(previous, current))
  end

  defp top_level_numbered_item?(line), do: String.match?(line, ~r/^\d+[.)]\s+/)

  defp separated_label?(line), do: label_line?(String.trim(line))

  defp starts_heading?(line), do: String.match?(String.trim_leading(line), ~r/^[#]{1,6}\s+/)

  defp ends_heading?(line), do: starts_heading?(line)

  defp quote_boundary?(previous, current), do: quote_line?(previous) != quote_line?(current)

  defp code_line_boundary?(previous, current),
    do: inline_code_line?(previous) != inline_code_line?(current)

  defp inline_code_line?(line), do: String.match?(String.trim(line), ~r/^`[^`].*`$/)
end
