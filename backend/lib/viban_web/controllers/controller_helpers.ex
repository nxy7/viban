defmodule VibanWeb.ControllerHelpers do
  @moduledoc """
  Shared helper functions for Phoenix controllers.

  Provides consistent error handling, response formatting, and common utilities
  used across multiple controllers in the application.

  ## Usage

  Import this module in your controller:

      defmodule VibanWeb.MyController do
        use VibanWeb, :controller
        import VibanWeb.ControllerHelpers

        def my_action(conn, params) do
          with {:ok, user} <- require_current_user(conn) do
            # ... action logic
          end
        end
      end

  ## Response Conventions

  All API responses follow a consistent format:
  - Success: `%{ok: true, ...data}`
  - Error: `%{ok: false, error: "message"}`
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn

  alias Viban.Accounts.User

  # ============================================================================
  # Authentication Helpers
  # ============================================================================

  @doc """
  Retrieves the current user from conn.assigns, returning an error tuple if not authenticated.

  This version does NOT halt the connection - use in `with` chains where you want to
  handle the error case yourself.

  ## Example

      def my_action(conn, params) do
        with {:ok, user} <- require_current_user(conn) do
          # proceed with authenticated user
        end
      end
  """
  @spec require_current_user(Plug.Conn.t()) :: {:ok, User.t()} | {:error, :not_authenticated}
  def require_current_user(conn) do
    case conn.assigns[:current_user] do
      nil -> {:error, :not_authenticated}
      user -> {:ok, user}
    end
  end

  @doc """
  Retrieves the current user from session, fetching from database.

  Use this when you need to get the user and the LoadUserFromSession plug
  has not been run (e.g., in browser pipeline routes).

  ## Example

      def my_action(conn, params) do
        with {:ok, user} <- get_user_from_session(conn) do
          # proceed with authenticated user
        end
      end
  """
  @spec get_user_from_session(Plug.Conn.t()) :: {:ok, User.t()} | {:error, :not_authenticated}
  def get_user_from_session(conn) do
    case get_session(conn, :user_id) do
      nil ->
        {:error, :not_authenticated}

      user_id ->
        case User.get(user_id) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, :not_authenticated}
        end
    end
  end

  # ============================================================================
  # Response Helpers
  # ============================================================================

  @doc """
  Sends a successful JSON response with the given data.

  Automatically wraps the data with `ok: true`.

  ## Example

      json_ok(conn, %{user: user_data})
      # Returns: %{ok: true, user: user_data}
  """
  @spec json_ok(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def json_ok(conn, data) when is_map(data) do
    json(conn, Map.put(data, :ok, true))
  end

  @doc """
  Sends an error JSON response with the given status and message.

  ## Example

      json_error(conn, :not_found, "Resource not found")
      # Returns 404 with: %{ok: false, error: "Resource not found"}

      json_error(conn, :unauthorized, "Not authenticated")
      # Returns 401 with: %{ok: false, error: "Not authenticated"}
  """
  @spec json_error(Plug.Conn.t(), atom(), String.t()) :: Plug.Conn.t()
  def json_error(conn, status, message) when is_atom(status) and is_binary(message) do
    conn
    |> put_status(status)
    |> json(%{ok: false, error: message})
  end

  @doc """
  Sends an error JSON response with additional details.

  ## Example

      json_error(conn, :unprocessable_entity, "Validation error", %{fields: ["name"]})
      # Returns 422 with: %{ok: false, error: "Validation error", details: %{fields: ["name"]}}
  """
  @spec json_error(Plug.Conn.t(), atom(), String.t(), map()) :: Plug.Conn.t()
  def json_error(conn, status, message, details) when is_atom(status) and is_map(details) do
    conn
    |> put_status(status)
    |> json(%{ok: false, error: message, details: details})
  end

  @doc """
  Sends an authentication error response (401) and halts the connection.

  Use this when you want to immediately stop processing for unauthenticated requests.

  ## Example

      case require_current_user(conn) do
        {:ok, user} -> # proceed
        {:error, :not_authenticated} -> halt_unauthenticated(conn)
      end
  """
  @spec halt_unauthenticated(Plug.Conn.t()) :: Plug.Conn.t()
  def halt_unauthenticated(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{ok: false, error: "Not authenticated. Please sign in."})
    |> halt()
  end

  # ============================================================================
  # Error Extraction Helpers
  # ============================================================================

  @doc """
  Extracts a human-readable error message from various error types.

  Handles:
  - Binary strings (passed through)
  - Ash.Error.Invalid structs (extracts messages from nested errors)
  - Ecto.Changeset (extracts validation errors)
  - Other values (inspected)

  ## Example

      extract_error_message(%Ash.Error.Invalid{errors: errors})
      # Returns: "field1: error1, field2: error2"

      extract_error_message("Simple error")
      # Returns: "Simple error"
  """
  @spec extract_error_message(any()) :: String.t()
  def extract_error_message(error) when is_binary(error), do: error

  def extract_error_message(%Ash.Error.Invalid{errors: errors}) do
    Enum.map_join(errors, ", ", &format_single_ash_error/1)
  end

  def extract_error_message(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  def extract_error_message(error), do: inspect(error)

  defp format_single_ash_error(%Ash.Error.Changes.InvalidAttribute{field: field, message: message}) do
    "#{field}: #{message}"
  end

  defp format_single_ash_error(%{message: msg}) when is_binary(msg), do: msg
  defp format_single_ash_error(error), do: inspect(error)

  # ============================================================================
  # Parameter Helpers
  # ============================================================================

  @doc """
  Gets an integer parameter from params with a default value.

  Handles both string and integer values.

  ## Example

      get_int_param(params, "page", 1)
      # Returns the integer value of params["page"], or 1 if not present
  """
  @spec get_int_param(map(), String.t(), integer()) :: integer()
  def get_int_param(params, key, default) when is_integer(default) do
    case Map.get(params, key) do
      nil -> default
      val when is_integer(val) -> val
      val when is_binary(val) -> String.to_integer(val)
    end
  end

  @doc """
  Gets a parameter value, supporting both string and atom keys.

  Useful for handling parameters that may come as either atoms or strings.

  ## Example

      get_param(params, :name)
      # Returns params["name"] || params[:name]
  """
  @spec get_param(map(), atom()) :: any()
  def get_param(params, key) when is_atom(key) do
    Map.get(params, to_string(key)) || Map.get(params, key)
  end

  @doc """
  Conditionally puts a value in a map if the value is not nil.

  ## Example

      %{}
      |> maybe_put(:title, params["title"])
      |> maybe_put(:body, params["body"])
      # Only includes keys where value is not nil
  """
  @spec maybe_put(map(), atom(), any()) :: map()
  def maybe_put(map, _key, nil), do: map
  def maybe_put(map, key, value), do: Map.put(map, key, value)

  # ============================================================================
  # VCS Error Handling (specific to VCS operations)
  # ============================================================================

  @doc """
  Handles common VCS (Version Control System) errors and returns appropriate responses.

  This provides consistent error handling for GitHub, GitLab, and other VCS providers.

  ## Example

      case VCS.list_repos(provider, token, opts) do
        {:ok, repos} -> json_ok(conn, %{repos: repos})
        error -> handle_vcs_error(conn, error, "Failed to fetch repositories")
      end
  """
  @spec handle_vcs_error(Plug.Conn.t(), {:error, atom() | tuple() | any()}, String.t()) ::
          Plug.Conn.t()
  def handle_vcs_error(conn, {:error, :unauthorized}, _context) do
    json_error(conn, :unauthorized, "VCS token expired. Please re-authenticate.")
  end

  def handle_vcs_error(conn, {:error, :not_found}, _context) do
    json_error(conn, :not_found, "Resource not found")
  end

  def handle_vcs_error(conn, {:error, {:validation_error, body}}, _context) do
    json_error(conn, :unprocessable_entity, "Validation error", body)
  end

  def handle_vcs_error(conn, {:error, reason}, context) do
    json_error(conn, :internal_server_error, "#{context}: #{inspect(reason)}")
  end

  # ============================================================================
  # Path Validation Helpers
  # ============================================================================

  @doc """
  Validates and opens a filesystem path, handling both files and directories.

  Used by EditorController and FolderController for path validation.

  Returns:
  - `{:ok, :directory, path}` - Path is a valid directory
  - `{:ok, :file, dir_path}` - Path is a file, returns parent directory
  - `{:error, :not_found, path}` - Path does not exist
  - `{:error, :access_denied, reason}` - Cannot access path

  ## Example

      case validate_path(path) do
        {:ok, :directory, dir_path} -> open_directory(dir_path)
        {:ok, :file, dir_path} -> open_directory(dir_path)
        {:error, :not_found, path} -> json_error(conn, :not_found, "Path does not exist")
        {:error, :access_denied, reason} -> json_error(conn, :unprocessable_entity, reason)
      end
  """
  @spec validate_path(String.t()) ::
          {:ok, :directory | :file, String.t()}
          | {:error, :not_found | :access_denied, String.t()}
  def validate_path(path) when is_binary(path) do
    case File.stat(path) do
      {:ok, %{type: :directory}} ->
        {:ok, :directory, path}

      {:ok, %{type: :regular}} ->
        {:ok, :file, Path.dirname(path)}

      {:error, :enoent} ->
        {:error, :not_found, path}

      {:error, reason} ->
        {:error, :access_denied, inspect(reason)}
    end
  end
end
