defmodule VibanWeb.Hologram.Layouts.MainLayout do
  use Hologram.Component

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <!DOCTYPE html>
    <html lang="en" class="h-full">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content="" />
        <title>Viban</title>

        <Hologram.UI.Runtime />

        <script src="https://cdn.tailwindcss.com"></script>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
        <link rel="stylesheet" href="/assets/hologram.css?v=7" />
        <script src="/assets/keyboard-shortcuts.js"></script>
        <script src="/assets/toast.js?v=2"></script>
        <script src="/assets/phoenix-channels.js?v=3"></script>
        <script src="/assets/sortable.js"></script>
        <script src="/assets/kanban-dnd.js?v=8"></script>
        <script src="/assets/task-interactions.js?v=7"></script>
        <script src="/assets/device-flow-polling.js?v=3"></script>
      </head>
      <body class="h-full bg-gray-950 text-white antialiased">
        <slot />
      </body>
    </html>
    """
  end
end
