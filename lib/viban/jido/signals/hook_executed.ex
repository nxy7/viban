defmodule Viban.Jido.Signals.HookExecuted do
  use Jido.Signal,
    type: "viban.hook.executed",
    default_source: "/viban/kanban/hooks",
    schema: [
      execution_id: [type: :string, required: true],
      hook_id: [type: :string, required: true],
      hook_name: [type: :string, required: true],
      task_id: [type: :string, required: true],
      triggering_column_id: [type: :string],
      status: [type: :atom, required: true]
    ]
end
