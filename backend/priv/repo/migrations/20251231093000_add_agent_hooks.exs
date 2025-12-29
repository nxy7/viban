defmodule Viban.Repo.Migrations.AddAgentHooks do
  @moduledoc """
  Add agent hook support to the hooks table.
  Adds hook_kind discriminator and agent-specific fields.
  """
  use Ecto.Migration

  def change do
    alter table(:hooks) do
      # Add hook kind discriminator - :script or :agent
      add :hook_kind, :string, default: "script", null: false

      # Agent-specific fields
      add :agent_prompt, :text
      add :agent_executor, :string
      add :agent_auto_approve, :boolean, default: false

      # Make command nullable (only required for script hooks)
      modify :command, :string, null: true
    end

    # Backfill existing hooks as script hooks
    execute "UPDATE hooks SET hook_kind = 'script' WHERE hook_kind IS NULL", ""
  end
end
