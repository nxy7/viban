defmodule Viban.BoardNameGenerator do
  @moduledoc """
  Generates human-readable board names from repository identifiers.
  """

  @spec from_repo_name(String.t() | nil) :: String.t()
  def from_repo_name(nil), do: ""
  def from_repo_name(""), do: ""

  def from_repo_name(repo_name) do
    repo_name
    |> extract_repo_part()
    |> split_into_words()
    |> capitalize_words()
    |> Enum.join(" ")
  end

  defp extract_repo_part(name) do
    name
    |> String.split("/")
    |> List.last()
  end

  defp split_into_words(name) do
    name
    |> String.split(~r/[-_]/)
  end

  defp capitalize_words(words) do
    Enum.map(words, fn word ->
      if all_uppercase?(word) do
        word
      else
        String.capitalize(word)
      end
    end)
  end

  defp all_uppercase?(word) do
    word == String.upcase(word) && String.length(word) > 1
  end
end
