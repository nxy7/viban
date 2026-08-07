defmodule Viban.Jido.Signals.ExecutorCompleted do
  use Jido.Signal,
    type: "viban.executor.completed",
    default_source: "/viban/executors",
    schema: [
      task_id: [type: :string, required: true],
      exit_code: [type: :integer],
      session_id: [type: :string]
    ]
end
