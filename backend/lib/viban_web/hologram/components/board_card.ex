defmodule VibanWeb.Hologram.Components.BoardCard do
  use Hologram.Component

  prop :board, :map, required: true

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <a
      href={board_url(@board.id)}
      class="block p-6 bg-gray-900 border border-gray-800 rounded-xl hover:border-gray-700 hover:bg-gray-800/50 transition-all"
    >
      <h3 class="text-lg font-semibold text-white mb-2">{@board.name}</h3>
      {%if @board.description}
        <p class="text-gray-400 text-sm">{@board.description}</p>
      {%else}
        <p class="text-gray-400 text-sm">No description</p>
      {/if}
    </a>
    """
  end

  defp board_url(id), do: "/board/" <> to_string(id)
end
