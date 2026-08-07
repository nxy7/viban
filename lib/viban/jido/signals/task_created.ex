defmodule Viban.Jido.Signals.TaskCreated do
  use Jido.Signal,
    type: "viban.task.created",
    default_source: "/viban/kanban",
    schema: [
      task_id: [type: :string, required: true],
      column_id: [type: :string, required: true]
    ]
end
