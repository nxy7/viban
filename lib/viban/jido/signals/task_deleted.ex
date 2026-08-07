defmodule Viban.Jido.Signals.TaskDeleted do
  use Jido.Signal,
    type: "viban.task.deleted",
    default_source: "/viban/kanban",
    schema: [
      task_id: [type: :string, required: true]
    ]
end
