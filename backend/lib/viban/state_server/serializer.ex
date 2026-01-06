defmodule Viban.StateServer.Serializer do
  @moduledoc """
  Filters non-serializable terms from GenServer state before persistence.

  Removes: PIDs, ports, references, functions, and other non-JSON-safe values.
  Converts atoms to strings for JSON safety.
  """

  @spec serialize(struct() | map()) :: map()
  def serialize(%{__struct__: module} = state) do
    state
    |> Map.from_struct()
    |> filter_non_serializable()
    |> Map.put("__struct__", to_string(module))
  end

  def serialize(state) when is_map(state) do
    filter_non_serializable(state)
  end

  @spec deserialize(map(), module()) :: map()
  def deserialize(data, module) when is_atom(module) and not is_nil(module) do
    data
    |> Map.delete("__struct__")
    |> Map.delete(:__struct__)
    |> atomize_keys()
    |> restore_struct(module)
  end

  def deserialize(data, nil), do: atomize_keys(data)

  defp restore_struct(data, module) do
    if function_exported?(module, :__struct__, 0) do
      struct(module, data)
    else
      data
    end
  end

  defp filter_non_serializable(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> non_serializable?(value) end)
    |> Map.new(fn {k, v} -> {stringify_key(k), filter_value(v)} end)
  end

  defp non_serializable?(value) do
    is_pid(value) or
      is_port(value) or
      is_reference(value) or
      is_function(value)
  end

  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key), do: key

  defp filter_value(value) when is_map(value) and not is_struct(value) do
    filter_non_serializable(value)
  end

  defp filter_value(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> filter_non_serializable()
  end

  defp filter_value(value) when is_list(value) do
    value
    |> Enum.reject(&non_serializable?/1)
    |> Enum.map(&filter_value/1)
  end

  defp filter_value(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.reject(&non_serializable?/1)
    |> Enum.map(&filter_value/1)
  end

  defp filter_value(value) when is_atom(value) and not is_boolean(value) and not is_nil(value) do
    Atom.to_string(value)
  end

  defp filter_value(value), do: value

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        atom_key = safe_to_atom(k)
        {atom_key, atomize_value(v)}

      {k, v} ->
        {k, atomize_value(v)}
    end)
  end

  defp atomize_keys(value), do: value

  defp atomize_value(map) when is_map(map), do: atomize_keys(map)
  defp atomize_value(list) when is_list(list), do: Enum.map(list, &atomize_value/1)
  defp atomize_value(value), do: value

  defp safe_to_atom(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError ->
      require Logger

      Logger.warning("[Serializer] Unknown atom during deserialization: #{inspect(string)}, keeping as string")
      string
  end
end
