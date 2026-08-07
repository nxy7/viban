defmodule Viban.Jido.Signals.TaskChanged do
  use Jido.Signal,
    type: "viban.task.changed",
    default_source: "/viban/kanban",
    schema: [
      task_id: [type: :string, required: true],
      action: [type: :atom, required: true],
      board_id: [type: :string]
    ]
end
