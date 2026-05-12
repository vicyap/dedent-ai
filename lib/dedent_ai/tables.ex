defmodule DedentAi.Tables do
  @moduledoc """
  Rewrites box-drawing ASCII tables (the shape Claude Code emits in terminals)
  into GFM-style Markdown tables, so a downstream Markdown renderer can produce
  real `<table>` elements instead of preformatted text.

  Looks for blocks bounded by `┌─┬─┐` and `└─┴─┘`, treats each `│ … │ … │` row
  as a data row, and treats the first row as the header. `├─┼─┤` lines between
  rows are absorbed as separators. A block that lacks a bottom border is left
  untouched.
  """

  @top ~r/^[ \t]*┌[─┬]+┐[ \t]*$/u
  @sep ~r/^[ \t]*├[─┼]+┤[ \t]*$/u
  @bot ~r/^[ \t]*└[─┴]+┘[ \t]*$/u
  @row ~r/^[ \t]*│.*│[ \t]*$/u

  @doc """
  Rewrites box-drawing tables in `text` to Markdown tables. Lines outside table
  blocks pass through unchanged.
  """
  @spec transform(binary()) :: binary()
  def transform(text) when is_binary(text) do
    text
    |> String.split("\n", trim: false)
    |> rewrite([])
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp rewrite([], acc), do: acc

  defp rewrite([line | rest] = lines, acc) do
    if String.match?(line, @top) do
      case extract(lines) do
        {:ok, md_lines, remaining} -> rewrite(remaining, Enum.reverse(md_lines) ++ acc)
        :no_table -> rewrite(rest, [line | acc])
      end
    else
      rewrite(rest, [line | acc])
    end
  end

  defp extract([_top | rest]) do
    case collect(rest, []) do
      {:ok, body, remaining} ->
        rows =
          body
          |> Enum.filter(&String.match?(&1, @row))
          |> Enum.map(&split_row/1)

        case rows do
          [] -> :no_table
          [header | data] -> {:ok, render(header, data), remaining}
        end

      :incomplete ->
        :no_table
    end
  end

  defp collect([], _acc), do: :incomplete

  defp collect([line | rest], acc) do
    cond do
      String.match?(line, @bot) -> {:ok, Enum.reverse(acc), rest}
      String.match?(line, @row) -> collect(rest, [line | acc])
      String.match?(line, @sep) -> collect(rest, [line | acc])
      true -> :incomplete
    end
  end

  defp split_row(line) do
    line
    |> String.trim()
    |> String.trim_leading("│")
    |> String.trim_trailing("│")
    |> String.split("│")
    |> Enum.map(&(&1 |> String.trim() |> escape_pipes()))
  end

  defp escape_pipes(cell), do: String.replace(cell, "|", "\\|")

  defp render(header, data_rows) do
    width = length(header)
    header_line = format_row(pad(header, width))
    separator_line = "|" <> String.duplicate(" --- |", width)
    data_lines = Enum.map(data_rows, fn row -> format_row(pad(row, width)) end)

    ["", header_line, separator_line] ++ data_lines ++ [""]
  end

  defp format_row(cells), do: "| " <> Enum.join(cells, " | ") <> " |"

  defp pad(row, width) when length(row) >= width, do: Enum.take(row, width)
  defp pad(row, width), do: row ++ List.duplicate("", width - length(row))
end
