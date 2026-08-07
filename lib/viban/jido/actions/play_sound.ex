defmodule Viban.Jido.Actions.PlaySound do
  use Jido.Action,
    name: "play_sound",
    description: "Play a sound effect on all connected clients",
    schema: [
      sound: [type: {:in, ["ding", "bell", "chime", "success", "notification"]}, required: true],
      task_id: [type: :string, required: true]
    ]

  def run(params, _context) do
    {:ok, %{effects: %{play_sound: %{sound: params.sound}}}}
  end
end
