defmodule VibanWeb.Hologram.Components.ColumnSettingsPopup do
  use Hologram.Component

  prop :is_open, :boolean, default: false
  prop :column, :map, default: nil
  prop :board_id, :string, default: nil
  prop :active_tab, :string, default: "general"

  # General tab state
  prop :column_name, :string, default: ""
  prop :column_color, :string, default: "#6366f1"
  prop :column_description, :string, default: ""
  prop :is_saving, :boolean, default: false
  prop :save_error, :string, default: nil
  prop :show_delete_confirm, :boolean, default: false
  prop :is_deleting, :boolean, default: false

  # Hooks tab state
  prop :hooks_enabled, :boolean, default: true
  prop :column_hooks, :list, default: []
  prop :available_hooks, :list, default: []
  prop :all_columns, :list, default: []
  prop :is_loading_hooks, :boolean, default: false
  prop :show_hook_picker, :boolean, default: false
  prop :is_adding_hook, :boolean, default: false

  # Concurrency tab state (only for In Progress column)
  prop :concurrency_enabled, :boolean, default: false
  prop :concurrency_limit, :integer, default: 3
  prop :is_saving_concurrency, :boolean, default: false

  @system_columns ["TODO", "In Progress", "To Review", "Done", "Cancelled"]
  @column_colors [
    "#6366f1",
    "#8b5cf6",
    "#ec4899",
    "#ef4444",
    "#f97316",
    "#eab308",
    "#22c55e",
    "#06b6d4",
    "#3b82f6",
    "#64748b"
  ]

  defp is_system_column?(name), do: name in @system_columns
  defp is_in_progress_column?(name), do: String.downcase(name || "") == "in progress"

  defp tab_class(tab, active_tab) do
    if tab == active_tab do
      "text-white border-b-2 border-brand-500 pb-1"
    else
      "text-gray-400"
    end
  end

  defp color_class(color, selected_color) do
    base = "w-6 h-6 rounded-full cursor-pointer transition-transform"

    if color == selected_color do
      base <> " scale-110 ring-2 ring-white ring-offset-2 ring-offset-gray-800"
    else
      base <> " hover:scale-105"
    end
  end

  defp get_hook_name(hook_id, available_hooks) do
    case Enum.find(available_hooks, &(&1["id"] == hook_id)) do
      nil -> "Unknown Hook"
      hook -> hook["name"]
    end
  end

  defp get_hook_is_system(hook_id, available_hooks) do
    case Enum.find(available_hooks, &(&1["id"] == hook_id)) do
      nil -> false
      hook -> hook["is_system"] == true
    end
  end

  defp is_play_sound_hook?(hook_id) do
    hook_id == "system:play-sound"
  end

  defp is_move_task_hook?(hook_id) do
    hook_id == "system:move-task"
  end

  defp get_hook_setting(column_hook, key, default) do
    settings = column_hook["hook_settings"] || %{}
    settings[key] || settings[to_string(key)] || default
  end

  @available_sounds [
    {"ding", "Ding", "Short, crisp notification"},
    {"bell", "Bell", "Gentle bell sound"},
    {"chime", "Chime", "Pleasant chime tone"},
    {"success", "Success", "Task completion tone"},
    {"notification", "Notification", "Standard notification"},
    {"woof", "Woof", "Friendly dog woof"},
    {"bark1", "Bark 1", "Dog bark variation 1"},
    {"bark2", "Bark 2", "Dog bark variation 2"},
    {"bark3", "Bark 3", "Dog bark variation 3"},
    {"bark4", "Bark 4", "Dog bark variation 4"},
    {"bark5", "Bark 5", "Dog bark variation 5"},
    {"bark6", "Bark 6", "Dog bark variation 6"}
  ]

  defp available_sounds, do: @available_sounds

  defp unassigned_hooks(column_hooks, available_hooks) do
    assigned_ids = Enum.map(column_hooks, & &1["hook_id"])
    Enum.filter(available_hooks, fn hook -> hook["id"] not in assigned_ids end)
  end

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @is_open && @column}
      <div class="fixed inset-0 z-50">
        <div class="fixed inset-0 bg-black/30" $click={action: :close_column_settings, target: "page"}></div>

        <div class="fixed z-50 w-80 bg-gray-800 border border-gray-700 rounded-lg shadow-xl" style="top: 120px; left: 50%; transform: translateX(-50%);">
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-700">
            <h3 class="font-semibold text-white">{@column[:name]} Settings</h3>
            <button
              type="button"
              class="text-gray-400 hover:text-white p-1"
              $click={action: :close_column_settings, target: "page"}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="flex border-b border-gray-700">
            <button
              type="button"
              class="flex-1 py-2 text-sm font-medium"
              $click={action: :set_column_settings_tab, params: %{tab: "general"}, target: "page"}
            >
              <span class={tab_class("general", @active_tab)}>General</span>
            </button>
            <button
              type="button"
              class="flex-1 py-2 text-sm font-medium"
              $click={action: :set_column_settings_tab, params: %{tab: "hooks"}, target: "page"}
            >
              <span class={tab_class("hooks", @active_tab)}>Hooks</span>
            </button>
            {%if is_in_progress_column?(@column[:name])}
              <button
                type="button"
                class="flex-1 py-2 text-sm font-medium"
                $click={action: :set_column_settings_tab, params: %{tab: "concurrency"}, target: "page"}
              >
                <span class={tab_class("concurrency", @active_tab)}>Limits</span>
              </button>
            {/if}
          </div>

          <div class="p-4 max-h-80 overflow-y-auto">
            {%if @active_tab == "general"}
              <div class="space-y-4">
                {%if @save_error}
                  <div class="p-2 bg-red-900/50 border border-red-800 rounded text-red-200 text-sm">
                    {@save_error}
                  </div>
                {/if}

                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Name</label>
                  <input
                    type="text"
                    class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed"
                    value={@column_name}
                    disabled={is_system_column?(@column[:name])}
                    $change={action: :update_column_name, target: "page"}
                  />
                  {%if is_system_column?(@column[:name])}
                    <p class="text-xs text-gray-500 mt-1">System columns cannot be renamed</p>
                  {/if}
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-2">Color</label>
                  <div class="flex flex-wrap gap-2">
                    {%for color <- column_colors()}
                      <button
                        type="button"
                        class={color_class(color, @column_color)}
                        style={"background-color: #{color}"}
                        $click={action: :select_column_color, params: %{color: color}, target: "page"}
                      ></button>
                    {/for}
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-300 mb-1">Description (optional)</label>
                  <textarea
                    rows="2"
                    class="w-full px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent resize-none"
                    placeholder="What should tasks in this column be doing?"
                    $change={action: :update_column_description, target: "page"}
                  >{@column_description}</textarea>
                </div>

                <button
                  type="button"
                  class="w-full px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  disabled={@is_saving}
                  $click={action: :save_column_settings, target: "page"}
                >
                  {%if @is_saving}Saving...{%else}Save Changes{/if}
                </button>

                <div class="pt-4 mt-4 border-t border-gray-700">
                  <h4 class="text-sm font-medium text-red-400 mb-2">Danger Zone</h4>
                  {%if @show_delete_confirm}
                    <div class="p-3 bg-red-900/20 border border-red-500/30 rounded-md space-y-2">
                      <p class="text-sm text-red-400">Delete all tasks in this column? This cannot be undone.</p>
                      <div class="flex gap-2">
                        <button
                          type="button"
                          class="flex-1 px-3 py-1.5 bg-gray-700 hover:bg-gray-600 text-gray-300 text-sm rounded transition-colors"
                          $click={action: :cancel_delete_column_tasks, target: "page"}
                        >Cancel</button>
                        <button
                          type="button"
                          class="flex-1 px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white text-sm rounded transition-colors disabled:opacity-50"
                          disabled={@is_deleting}
                          $click={action: :confirm_delete_column_tasks, target: "page"}
                        >
                          {%if @is_deleting}Deleting...{%else}Delete All{/if}
                        </button>
                      </div>
                    </div>
                  {%else}
                    <button
                      type="button"
                      class="w-full px-4 py-2 bg-red-600/20 hover:bg-red-600/30 text-red-400 border border-red-500/30 rounded-lg transition-colors"
                      $click={action: :show_delete_column_tasks_confirm, target: "page"}
                    >Delete All Tasks</button>
                  {/if}
                </div>
              </div>
            {/if}

            {%if @active_tab == "hooks"}
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-300">Hooks enabled</span>
                  <button
                    type="button"
                    class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors " <> if(@hooks_enabled, do: "bg-brand-600", else: "bg-gray-600")}
                    $click={action: :toggle_column_hooks_enabled, target: "page"}
                  >
                    <span class={"inline-block h-4 w-4 transform rounded-full bg-white transition-transform " <> if(@hooks_enabled, do: "translate-x-6", else: "translate-x-1")}></span>
                  </button>
                </div>

                {%if @is_loading_hooks}
                  <div class="text-gray-500 text-xs text-center py-4">Loading hooks...</div>
                {%else}
                  <div class="space-y-2">
                    <div class="flex items-center justify-between">
                      <div>
                        <h4 class="text-sm font-medium text-gray-200">On Entry</h4>
                        <p class="text-xs text-gray-500">Run when task enters this column</p>
                      </div>
                      {%if length(unassigned_hooks(@column_hooks, @available_hooks)) > 0}
                        <button
                          type="button"
                          class="text-sm text-brand-400 hover:text-brand-300"
                          $click={action: :toggle_hook_picker, target: "page"}
                        >+ Add</button>
                      {%else}
                        {%if length(@column_hooks) > 0 && length(@available_hooks) > 0}
                          <span class="text-xs text-gray-500 italic">All hooks assigned</span>
                        {/if}
                      {/if}
                    </div>

                    {%if @show_hook_picker}
                      <div class="bg-gray-900 border border-gray-700 rounded-md p-2 space-y-1">
                        {%for hook <- unassigned_hooks(@column_hooks, @available_hooks)}
                          <button
                            type="button"
                            class="w-full px-3 py-2 text-left text-sm text-gray-300 hover:bg-gray-800 rounded flex items-center justify-between"
                            disabled={@is_adding_hook}
                            $click={action: :add_column_hook, params: %{hook_id: hook["id"]}, target: "page"}
                          >
                            <span class="truncate">{hook["name"]}</span>
                            {%if hook["is_system"]}
                              <span class="px-1.5 py-0.5 text-xs bg-purple-500/20 text-purple-400 rounded">System</span>
                            {/if}
                          </button>
                        {/for}
                      </div>
                    {/if}

                    <div class="space-y-1">
                      {%if length(@column_hooks) > 0}
                        {%for column_hook <- @column_hooks}
                          <div class="p-2 bg-gray-900 rounded-md">
                            <div class="flex items-center gap-2">
                              <svg class="w-3.5 h-3.5 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                              </svg>
                              <span class="text-sm text-white truncate flex-1">{get_hook_name(column_hook["hook_id"], @available_hooks)}</span>
                              <div class="flex items-center gap-0.5 flex-shrink-0">
                                <button
                                  type="button"
                                  class={"px-1.5 py-0.5 text-xs rounded border " <> if(column_hook["execute_once"], do: "bg-yellow-500/20 text-yellow-400 border-yellow-500/30", else: "bg-gray-700/50 text-gray-500 border-gray-600/30")}
                                  title={if(column_hook["execute_once"], do: "Runs only once per task", else: "Runs every time")}
                                  $click={action: :toggle_hook_execute_once, params: %{column_hook_id: column_hook["id"]}, target: "page"}
                                >
                                  {%if column_hook["execute_once"]}1x{%else}∞{/if}
                                </button>
                                <button
                                  type="button"
                                  class={"px-1.5 py-0.5 text-xs rounded border " <> if(column_hook["transparent"], do: "bg-blue-500/20 text-blue-400 border-blue-500/30", else: "bg-gray-700/50 text-gray-500 border-gray-600/30")}
                                  title={if(column_hook["transparent"], do: "Transparent: runs even on error", else: "Normal: skipped on error")}
                                  $click={action: :toggle_hook_transparent, params: %{column_hook_id: column_hook["id"]}, target: "page"}
                                >
                                  {%if column_hook["transparent"]}T{%else}N{/if}
                                </button>
                                {%if column_hook["removable"] != false}
                                  <button
                                    type="button"
                                    class="p-1 text-gray-400 hover:text-white"
                                    $click={action: :remove_column_hook, params: %{column_hook_id: column_hook["id"]}, target: "page"}
                                  >
                                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                                    </svg>
                                  </button>
                                {/if}
                              </div>
                            </div>
                            <div class="flex items-center gap-2 mt-1.5">
                              {%if get_hook_is_system(column_hook["hook_id"], @available_hooks)}
                                <span class="px-1.5 py-0.5 text-xs bg-purple-500/20 text-purple-400 rounded">System</span>
                              {/if}
                              {%if column_hook["removable"] == false}
                                <span class="px-1.5 py-0.5 text-xs bg-gray-700/50 text-gray-400 rounded">Required</span>
                              {/if}
                            </div>
                            {%if is_play_sound_hook?(column_hook["hook_id"])}
                              <div class="mt-2 pt-2 border-t border-gray-700/50">
                                <label class="block text-xs text-gray-400 mb-1">Sound</label>
                                <div class="flex gap-2">
                                  <select
                                    id={"sound-select-#{column_hook["id"]}"}
                                    class="flex-1 px-2 py-1.5 text-sm bg-gray-800 border border-gray-700 rounded text-white focus:outline-none focus:ring-1 focus:ring-brand-500"
                                    $change={action: :update_hook_sound, params: %{column_hook_id: column_hook["id"]}, target: "page"}
                                  >
                                    {%for {value, name, _desc} <- available_sounds()}
                                      <option value={value} selected={get_hook_setting(column_hook, "sound", "ding") == value}>{name}</option>
                                    {/for}
                                  </select>
                                  <button
                                    type="button"
                                    class="px-2 py-1.5 text-sm bg-gray-700 hover:bg-gray-600 border border-gray-600 rounded text-white transition-colors"
                                    onclick={"VibanChannels && VibanChannels.playSound(document.getElementById('sound-select-#{column_hook["id"]}').value)"}
                                    title="Preview sound"
                                  >
                                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path>
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                                    </svg>
                                  </button>
                                </div>
                              </div>
                            {/if}
                            {%if is_move_task_hook?(column_hook["hook_id"])}
                              <div class="mt-2 pt-2 border-t border-gray-700/50">
                                <label class="block text-xs text-gray-400 mb-1">Target Column</label>
                                <select
                                  class="w-full px-2 py-1.5 text-sm bg-gray-800 border border-gray-700 rounded text-white focus:outline-none focus:ring-1 focus:ring-brand-500"
                                  $change={action: :update_hook_target_column, params: %{column_hook_id: column_hook["id"]}, target: "page"}
                                >
                                  <option value="next" selected={get_hook_setting(column_hook, "target_column", "next") == "next"}>Next Column</option>
                                  {%for col <- @all_columns}
                                    {%if col[:id] != @column[:id]}
                                      <option value={col[:name]} selected={get_hook_setting(column_hook, "target_column", "next") == col[:name]}>{col[:name]}</option>
                                    {/if}
                                  {/for}
                                </select>
                                <p class="text-xs text-gray-500 mt-1">Where to move the task when this hook runs</p>
                              </div>
                            {/if}
                          </div>
                        {/for}
                      {%else}
                        <p class="text-xs text-gray-600 italic py-1">No hooks assigned</p>
                      {/if}
                    </div>
                  </div>
                {/if}
              </div>
            {/if}

            {%if @active_tab == "concurrency"}
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <div>
                    <h4 class="text-sm font-medium text-gray-200">Limit Concurrent Tasks</h4>
                    <p class="text-xs text-gray-500 mt-0.5">Control how many tasks can run at once</p>
                  </div>
                  <button
                    type="button"
                    class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors " <> if(@concurrency_enabled, do: "bg-brand-600", else: "bg-gray-600")}
                    disabled={@is_saving_concurrency}
                    $click={action: :toggle_concurrency_enabled, target: "page"}
                  >
                    <span class={"inline-block h-4 w-4 transform rounded-full bg-white transition-transform " <> if(@concurrency_enabled, do: "translate-x-6", else: "translate-x-1")}></span>
                  </button>
                </div>

                {%if @concurrency_enabled}
                  <div class="space-y-4 pl-3 border-l-2 border-brand-500/30">
                    <div>
                      <label class="block text-sm font-medium text-gray-300 mb-2">Maximum Concurrent Tasks</label>
                      <div class="flex items-center gap-3">
                        <input
                          type="number"
                          min="1"
                          max="100"
                          class="w-20 px-3 py-2 bg-gray-900 border border-gray-700 rounded-lg text-white text-center focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-transparent"
                          value={@concurrency_limit}
                          $change={action: :update_concurrency_limit, target: "page"}
                        />
                        <span class="text-sm text-gray-400">tasks at once</span>
                      </div>
                    </div>

                    <button
                      type="button"
                      class="w-full px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors disabled:opacity-50"
                      disabled={@is_saving_concurrency}
                      $click={action: :save_concurrency_settings, target: "page"}
                    >
                      {%if @is_saving_concurrency}Saving...{%else}Save Limit{/if}
                    </button>
                  </div>
                {/if}

                <div class="p-3 bg-blue-900/20 border border-blue-500/30 rounded-lg">
                  <p class="text-xs text-blue-300">
                    <svg class="w-4 h-4 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    When the limit is reached, new tasks will queue and start automatically when a slot becomes available.
                  </p>
                </div>
              </div>
            {/if}
          </div>
        </div>
      </div>
    {/if}
    """
  end

  defp column_colors, do: @column_colors
end
