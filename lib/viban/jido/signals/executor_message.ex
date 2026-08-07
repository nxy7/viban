defmodule Viban.Jido.Signals.ExecutorMessage do
  use Jido.Signal,
    type: "viban.executor.message",
    default_source: "/viban/executors",
    schema: [
      id: [type: :string, required: true],
      task_id: [type: :string, required: true],
      role: [type: :atom, required: true],
      content: [type: :string],
      session_id: [type: :string]
    ]
end
