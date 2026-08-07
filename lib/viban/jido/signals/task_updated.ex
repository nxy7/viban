defmodule Viban.Jido.Signals.TaskUpdated do
  use Jido.Signal,
    type: "viban.task.updated",
    default_source: "/viban/kanban",
    schema: [
      task_id: [type: :string, required: true],
      column_id: [type: :string, required: true]
    ]
end
