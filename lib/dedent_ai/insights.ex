defmodule DedentAi.Insights do
  @moduledoc """
  Heuristic extraction of "insight" callouts from terminal-paste text.

  Recognizes Claude Code's `★ Insight ────` blocks (and ASCII variants) by
  matching an opener line, capturing indented content, and stopping at a
  closing rule line.
  """

  @opener ~r/^(?<indent>[ \t]*)★\s*Insight\s*[─━—\-=]{3,}\s*$/u
  @closer ~r/^[ \t]*[─━—\-=]{3,}\s*$/u

  @doc """
  Returns insight bodies extracted from `text` in source order.
  """
  @spec extract(binary()) :: [binary()]
  def extract(text) when is_binary(text) do
    text
    |> String.split("\n", trim: false)
    |> scan([], :outside, "", [])
    |> Enum.reverse()
  end

  defp scan([], acc, _state, _indent, _buffer), do: acc

  defp scan([line | rest], acc, :outside, _indent, _buffer) do
    case Regex.named_captures(@opener, line) do
      %{"indent" => indent} -> scan(rest, acc, :inside, indent, [])
      _ -> scan(rest, acc, :outside, "", [])
    end
  end

  defp scan([line | rest], acc, :inside, indent, buffer) do
    cond do
      Regex.match?(@closer, line) ->
        body = buffer |> Enum.reverse() |> Enum.join("\n") |> String.trim()
        acc = if body == "", do: acc, else: [body | acc]
        scan(rest, acc, :outside, "", [])

      true ->
        scan(rest, acc, :inside, indent, [strip_indent(line, indent) | buffer])
    end
  end

  defp strip_indent(line, ""), do: line

  defp strip_indent(line, indent) do
    if String.starts_with?(line, indent) do
      String.replace_prefix(line, indent, "")
    else
      String.trim_leading(line)
    end
  end
end
