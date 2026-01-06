defmodule Viban.Executors.Registry do
  @moduledoc """
  Registry of available executor implementations.

  This module provides functions to discover and query available executors
  on the current system.
  """

  alias Viban.Executors.Implementations.ClaudeCode
  alias Viban.Executors.Implementations.GeminiCLI

  @executors [
    ClaudeCode,
    GeminiCLI
    # Add more executors here as they're implemented:
    # Codex,
    # OpenCode,
  ]

  @doc """
  List all registered executor modules.
  """
  def all do
    @executors
  end

  @doc """
  List all executors that are available on the current system.
  Returns a list of maps with executor information.
  """
  def list_available do
    @executors
    |> Enum.filter(& &1.available?())
    |> Enum.map(&executor_info/1)
  end

  @doc """
  List all executors (available or not) with their availability status.
  """
  def list_all do
    Enum.map(@executors, &executor_info/1)
  end

  @doc """
  Get an executor module by its type atom.
  """
  def get_by_type(type) do
    Enum.find(@executors, fn executor ->
      executor.type() == type
    end)
  end

  @doc """
  Get executor information by type.
  """
  def get_info(type) do
    case get_by_type(type) do
      nil -> {:error, :not_found}
      executor -> {:ok, executor_info(executor)}
    end
  end

  @doc """
  Check if an executor type is available.
  """
  def available?(type) do
    case get_by_type(type) do
      nil -> false
      executor -> executor.available?()
    end
  end

  defp executor_info(executor) do
    %{
      name: executor.name(),
      type: to_string(executor.type()),
      available: executor.available?(),
      capabilities: Enum.map(executor.capabilities(), &to_string/1)
    }
  end
end
