defmodule Viban.StateServer.ActorState do
  @moduledoc """
  Persists GenServer state for StateServer instances.

  Allows stateful GenServers to survive restarts by storing their
  serializable state in PostgreSQL as JSONB.

  ## Status Lifecycle

  - `:starting` - Actor is initializing
  - `:ok` - Actor is running normally
  - `:stopping` - Actor is gracefully shutting down
  - `:stopped` - Actor has stopped (set by Monitor on process death)
  - `:error` - Actor encountered an error (set manually via set_status)
  """

  use Ash.Resource,
    domain: Viban.StateServer,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  typescript do
    type_name("ActorState")
  end

  postgres do
    table "actor_states"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :actor_type, :string do
      allow_nil? false
      public? true

      description "Module name of the StateServer (e.g., 'Elixir.Viban.Kanban.HookExecution.HookExecutionServer')"
    end

    attribute :actor_id, :string do
      allow_nil? false
      public? true
      description "Unique identifier for the actor instance (e.g., task_id)"
    end

    attribute :state, :map do
      allow_nil? false
      default %{}
      public? true
      description "Serialized state as JSONB"
    end

    attribute :status, :atom do
      allow_nil? false
      default :starting
      public? true
      constraints one_of: [:starting, :ok, :stopping, :stopped, :error]
      description "Current lifecycle status"
    end

    attribute :message, :string do
      public? true
      description "Human-readable status message (e.g., error description)"
    end

    attribute :version, :integer do
      allow_nil? false
      default 1
      public? true
      description "Optimistic locking version"
    end

    timestamps()
  end

  identities do
    identity :unique_actor, [:actor_type, :actor_id]
  end

  actions do
    defaults [:read, :destroy]

    create :upsert do
      accept [:actor_type, :actor_id, :state, :status, :message]
      primary? true
      upsert? true
      upsert_identity :unique_actor
      upsert_fields [:state, :status, :message, :version, :updated_at]

      change increment(:version)
    end

    update :update_status do
      accept [:status, :message]
      change increment(:version)
    end

    update :save_state do
      accept [:state]
      change increment(:version)
    end

    action :set_demo_text, :map do
      argument :text, :string, allow_nil?: false

      run fn input, _context ->
        Viban.StateServer.DemoAgent.set_text(input.arguments.text)
        {:ok, %{success: true}}
      end
    end
  end

  code_interface do
    define :upsert
    define :update_status
    define :save_state
    define :destroy
    define :get_by_actor, action: :read, get_by: [:actor_type, :actor_id]
  end
end
