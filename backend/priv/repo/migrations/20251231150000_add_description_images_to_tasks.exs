defmodule Viban.Repo.Migrations.AddDescriptionImagesToTasks do
  @moduledoc """
  Add description_images column to tasks table.
  This stores metadata about images embedded in task descriptions.
  """

  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add :description_images, {:array, :map}, default: []
    end
  end
end
