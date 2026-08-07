defmodule Viban.Jido.Signals.HookEffect do
  use Jido.Signal,
    type: "viban.hook.effect",
    default_source: "/viban/kanban/hooks",
    schema: [
      execution_id: [type: :string, required: true],
      hook_id: [type: :string, required: true],
      hook_name: [type: :string, required: true],
      task_id: [type: :string, required: true],
      effects: [type: :map, required: true]
    ]
end
