defmodule Viban.Repo.Migrations.ChangeTaskPositionToDecimal do
  @moduledoc """
  Changes task position from integer to decimal to support fractional positioning
  during drag-and-drop reordering.
  """

  use Ecto.Migration

  def up do
    alter table(:tasks) do
      modify :position, :decimal, default: 0
    end
  end

  def down do
    alter table(:tasks) do
      modify :position, :bigint, default: 0
    end
  end
end
