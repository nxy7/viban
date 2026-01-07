defmodule Viban.AppRuntime.AppUpdates.State do
  @moduledoc """
  State persistence for update checker in ~/.viban/update_state.json
  """

  @data_dir Path.expand("~/.viban")
  @state_file Path.join(@data_dir, "update_state.json")

  @type t :: %{
          optional(:last_check) => String.t(),
          optional(:latest_version) => String.t(),
          optional(:release_url) => String.t(),
          optional(:assets) => %{String.t() => String.t()}
        }

  @spec get() :: t()
  def get do
    case File.read(@state_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, state} -> state
          {:error, _} -> %{}
        end

      {:error, :enoent} ->
        %{}

      {:error, _} ->
        %{}
    end
  end

  @spec put(t()) :: :ok | {:error, term()}
  def put(updates) when is_map(updates) do
    File.mkdir_p!(@data_dir)

    state =
      get()
      |> Map.merge(updates)
      |> Map.put("last_check", DateTime.to_iso8601(DateTime.utc_now()))

    content = Jason.encode!(state, pretty: true)

    case File.write(@state_file, content) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec platform_target() :: :macos_arm | :macos_intel | :linux_intel | :linux_arm | :unknown
  def platform_target do
    arch = :system_architecture |> :erlang.system_info() |> to_string()

    case :os.type() do
      {:unix, :darwin} ->
        if String.contains?(arch, "arm") or String.contains?(arch, "aarch64") do
          :macos_arm
        else
          :macos_intel
        end

      {:unix, :linux} ->
        cond do
          String.contains?(arch, "x86_64") -> :linux_intel
          String.contains?(arch, "arm") or String.contains?(arch, "aarch64") -> :linux_arm
          true -> :unknown
        end

      _ ->
        :unknown
    end
  end

  @spec current_version() :: String.t()
  def current_version do
    :viban |> Application.spec(:vsn) |> to_string()
  end
end
