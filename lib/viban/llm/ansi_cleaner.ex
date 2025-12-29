defmodule Viban.LLM.AnsiCleaner do
  @moduledoc """
  Utility module for cleaning ANSI escape codes and terminal control sequences
  from CLI output.

  This is commonly needed when capturing output from CLI tools that use PTY
  wrappers (like `script`) which preserve terminal formatting codes.
  """

  @doc """
  Removes ANSI escape codes and normalizes the output string.

  Handles:
  - ANSI escape codes (colors, cursor movement, etc.)
  - OSC sequences (terminal title, etc.)
  - DCS/SOS/PM/APC sequences
  - Cursor show/hide codes
  - Carriage returns and line ending normalization
  - Collapses multiple newlines

  ## Examples

      iex> AnsiCleaner.clean("\\e[31mRed text\\e[0m")
      "Red text"

      iex> AnsiCleaner.clean("Line 1\\r\\nLine 2")
      "Line 1\\nLine 2"
  """
  @spec clean(String.t()) :: String.t()
  def clean(output) when is_binary(output) do
    output
    # Remove ANSI escape codes (ESC [ ... letter) - includes private mode sequences with ?
    |> String.replace(~r/\x1b\[[0-9;?]*[a-zA-Z]/, "")
    # Alternative escape notation
    |> String.replace(~r/\e\[[0-9;?]*[a-zA-Z]/, "")
    # Remove orphaned cursor show/hide codes (when ESC was already stripped)
    |> String.replace(~r/\[\?25[hl]/, "")
    # Remove standalone private mode sequences that may appear without ESC
    |> String.replace(~r/\[\?\d+[a-zA-Z]/, "")
    # Remove OSC sequences (ESC ] ... BEL)
    |> String.replace(~r/\x1b\].*?\x07/, "")
    # Remove DCS/SOS/PM/APC sequences
    |> String.replace(~r/\x1b[PX^_].*?\x1b\\/, "")
    # Normalize line endings
    |> String.replace(~r/\r\n/, "\n")
    # Handle remaining carriage returns
    |> String.replace(~r/\r/, "\n")
    |> String.trim()
    # Collapse multiple newlines
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  def clean(nil), do: ""
end
