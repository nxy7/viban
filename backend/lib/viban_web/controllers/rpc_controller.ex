defmodule VibanWeb.RpcController do
  @moduledoc """
  Generic RPC endpoint for Ash resource actions.

  Provides a flexible way to invoke Ash actions via HTTP. This is useful for
  operations that don't fit neatly into REST conventions or when you need
  to invoke custom Ash actions.

  ## Security

  This controller allows execution of any Ash action on configured domains.
  The allowed domains are restricted via the `@allowed_domains` module attribute.

  ## Request Format

  All requests are POST to `/api/rpc/run` with the following body:

      {
        "domain": "Kanban",
        "resource": "Task",
        "action": "create",
        "input": { ... },
        "id": "uuid"  // Required for update/destroy actions
      }

  ## Action Types

  - `:create` - Creates a new record
  - `:update` - Updates an existing record (requires `id`)
  - `:destroy` - Deletes a record (requires `id`)
  - `:read` - Reads records
  - `:action` - Executes a generic action

  ## Response Format

  Success:
      {"ok": true, "result": { ... }}

  Error:
      {"ok": false, "error": "Error message"}
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers, only: [json_ok: 2, json_error: 3, extract_error_message: 1]

  require Logger

  # Allowed domains for RPC calls - security restriction
  @allowed_domains ~w(Kanban Messages Accounts Executors)

  @doc """
  Handles RPC calls to Ash resources.

  ## Body Parameters

  - `domain` (required) - The Ash domain name (e.g., "Kanban")
  - `resource` (required) - The resource name within the domain (e.g., "Task")
  - `action` (required) - The action to execute (e.g., "create", "update")
  - `input` - Parameters to pass to the action (default: %{})
  - `id` - Record ID, required for update/destroy actions
  """
  @spec run(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def run(conn, %{"domain" => domain, "resource" => resource, "action" => action} = params) do
    with :ok <- validate_domain(domain),
         {:ok, resource_module} <- resolve_resource_module(domain, resource),
         {:ok, action_atom} <- parse_action(action),
         {:ok, action_type} <- get_action_type(resource_module, action_atom) do
      input = Map.get(params, "input", %{})
      record_id = Map.get(params, "id")

      execute_action(conn, resource_module, action_type, action_atom, input, record_id)
    else
      {:error, :invalid_domain} ->
        json_error(conn, :forbidden, "Domain '#{domain}' is not allowed for RPC calls")

      {:error, :invalid_resource} ->
        json_error(conn, :not_found, "Resource '#{resource}' not found in domain '#{domain}'")

      {:error, :invalid_action} ->
        json_error(conn, :bad_request, "Invalid action: #{action}")

      {:error, :unknown_action} ->
        json_error(conn, :not_found, "Action '#{action}' not found on resource")

      {:error, reason} ->
        json_error(conn, :bad_request, extract_error_message(reason))
    end
  end

  def run(conn, _params) do
    json_error(conn, :bad_request, "Missing required parameters: domain, resource, action")
  end

  # ============================================================================
  # Private Functions - Validation
  # ============================================================================

  defp validate_domain(domain) do
    if domain in @allowed_domains do
      :ok
    else
      {:error, :invalid_domain}
    end
  end

  defp resolve_resource_module(domain, resource) do
    # Use to_existing_atom to prevent atom table exhaustion attacks.
    # Domain is already validated against @allowed_domains, but we still
    # use to_existing_atom for safety. Resource names must exist as atoms.
    domain_module = Module.concat([Viban, String.to_existing_atom(domain)])
    resource_module = Module.concat([domain_module, String.to_existing_atom(resource)])

    if Code.ensure_loaded?(resource_module) do
      {:ok, resource_module}
    else
      {:error, :invalid_resource}
    end
  rescue
    ArgumentError -> {:error, :invalid_resource}
  end

  defp parse_action(action) when is_binary(action) do
    {:ok, String.to_existing_atom(action)}
  rescue
    ArgumentError -> {:error, :invalid_action}
  end

  defp get_action_type(resource_module, action_atom) do
    case Ash.Resource.Info.action(resource_module, action_atom) do
      nil -> {:error, :unknown_action}
      action -> {:ok, action.type}
    end
  end

  # ============================================================================
  # Private Functions - Action Execution
  # ============================================================================

  defp execute_action(conn, resource_module, :create, action_atom, input, _record_id) do
    case Ash.create(resource_module, input, action: action_atom) do
      {:ok, result} ->
        json_ok(conn, %{result: serialize_result(result)})

      {:error, error} ->
        json_error(conn, :unprocessable_entity, extract_error_message(error))
    end
  end

  defp execute_action(conn, resource_module, :update, action_atom, input, record_id) do
    with {:ok, record} <- fetch_record(resource_module, record_id),
         {:ok, result} <- Ash.update(record, input, action: action_atom) do
      json_ok(conn, %{result: serialize_result(result)})
    else
      {:error, :record_not_found} ->
        json_error(conn, :not_found, "Record not found")

      {:error, :id_required} ->
        json_error(conn, :bad_request, "ID is required for update actions")

      {:error, error} ->
        json_error(conn, :unprocessable_entity, extract_error_message(error))
    end
  end

  defp execute_action(conn, resource_module, :destroy, action_atom, _input, record_id) do
    with {:ok, record} <- fetch_record(resource_module, record_id) do
      case Ash.destroy(record, action: action_atom) do
        :ok ->
          json_ok(conn, %{result: %{deleted: true, id: record_id}})

        {:ok, destroyed} ->
          json_ok(conn, %{result: serialize_result(destroyed)})

        {:error, error} ->
          json_error(conn, :unprocessable_entity, extract_error_message(error))
      end
    else
      {:error, :record_not_found} ->
        json_error(conn, :not_found, "Record not found")

      {:error, :id_required} ->
        json_error(conn, :bad_request, "ID is required for destroy actions")
    end
  end

  defp execute_action(conn, resource_module, :read, action_atom, _input, _record_id) do
    case Ash.read(resource_module, action: action_atom) do
      {:ok, results} ->
        json_ok(conn, %{result: serialize_result(results)})

      {:error, error} ->
        json_error(conn, :unprocessable_entity, extract_error_message(error))
    end
  end

  defp execute_action(conn, resource_module, :action, action_atom, input, _record_id) do
    action_input = Ash.ActionInput.for_action(resource_module, action_atom, input)

    case Ash.run_action(action_input) do
      {:ok, result} ->
        json_ok(conn, %{result: serialize_result(result)})

      {:error, error} ->
        json_error(conn, :unprocessable_entity, extract_error_message(error))
    end
  end

  defp execute_action(conn, _resource_module, action_type, _action_atom, _input, _record_id) do
    json_error(conn, :bad_request, "Unsupported action type: #{action_type}")
  end

  defp fetch_record(_resource_module, nil), do: {:error, :id_required}

  defp fetch_record(resource_module, id) do
    case Ash.get(resource_module, id) do
      {:ok, nil} -> {:error, :record_not_found}
      {:ok, record} -> {:ok, record}
      {:error, _} -> {:error, :record_not_found}
    end
  end

  # ============================================================================
  # Private Functions - Serialization
  # ============================================================================

  defp serialize_result(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([
      :__meta__,
      :__struct__,
      :__metadata__,
      :__order__,
      :__lateral_join_source__,
      :aggregates,
      :calculations
    ])
    |> Enum.reject(fn {_k, v} ->
      match?(%Ash.NotLoaded{}, v) || match?(%Ecto.Association.NotLoaded{}, v)
    end)
    |> Enum.into(%{}, fn {k, v} -> {k, serialize_value(v)} end)
  end

  defp serialize_result(list) when is_list(list) do
    Enum.map(list, &serialize_result/1)
  end

  defp serialize_result(other), do: other

  defp serialize_value(%Ecto.Association.NotLoaded{}), do: nil
  defp serialize_value(%Ash.NotLoaded{}), do: nil
  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(%Date{} = d), do: Date.to_iso8601(d)

  defp serialize_value(atom) when is_atom(atom) and not is_nil(atom) and not is_boolean(atom) do
    Atom.to_string(atom)
  end

  defp serialize_value(value), do: value
end
