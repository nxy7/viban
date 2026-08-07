defmodule Viban.Jido.Signals.ExecutorSessionUpdate do
  use Jido.Signal,
    type: "viban.executor.session_update",
    default_source: "/viban/executors",
    schema: [
      id: [type: :string, required: true],
      task_id: [type: :string, required: true],
      status: [type: :atom, required: true]
    ]
end
