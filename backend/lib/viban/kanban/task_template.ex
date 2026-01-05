defmodule Viban.Kanban.TaskTemplate do
  use Ash.Resource,
    domain: Viban.Kanban,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshTypescript.Resource]

  typescript do
    type_name("TaskTemplate")
  end

  postgres do
    table "task_templates"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints max_length: 100
    end

    attribute :description_template, :string do
      public? true
      constraints max_length: 10_000
    end

    attribute :position, :integer do
      public? true
      default 0
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :board, Viban.Kanban.Board do
      allow_nil? false
      public? true
      attribute_writable? true
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :description_template, :position, :board_id]
      primary? true
    end

    update :update do
      accept [:name, :description_template, :position]
      primary? true
    end

    destroy :destroy do
      primary? true
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :get, action: :read, get_by: [:id]
  end
end
