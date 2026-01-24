defmodule VibanWeb.Hologram.Components.BoardSettingsPanel do
  use Hologram.Component

  prop :is_open, :boolean, default: false
  prop :board, :map, default: nil
  prop :columns, :list, default: []
  prop :active_tab, :string, default: "general"

  prop :repository, :map, default: nil
  prop :is_loading_repository, :boolean, default: false
  prop :is_editing_repository, :boolean, default: false
  prop :repository_name, :string, default: ""
  prop :repository_path, :string, default: ""
  prop :repository_default_branch, :string, default: "main"
  prop :repository_error, :string, default: nil
  prop :is_saving_repository, :boolean, default: false

  prop :hooks, :list, default: []
  prop :is_loading_hooks, :boolean, default: false
  prop :is_creating_hook, :boolean, default: false
  prop :editing_hook, :map, default: nil
  prop :hook_name, :string, default: ""
  prop :hook_kind, :string, default: "script"
  prop :hook_command, :string, default: ""
  prop :hook_agent_prompt, :string, default: ""
  prop :hook_agent_executor, :string, default: "claude_code"
  prop :hook_agent_auto_approve, :boolean, default: false
  prop :hook_error, :string, default: nil
  prop :is_saving_hook, :boolean, default: false

  prop :task_templates, :list, default: []
  prop :is_loading_templates, :boolean, default: false
  prop :is_creating_template, :boolean, default: false
  prop :editing_template, :map, default: nil
  prop :template_name, :string, default: ""
  prop :template_description, :string, default: ""
  prop :template_error, :string, default: nil
  prop :is_saving_template, :boolean, default: false

  prop :periodical_tasks, :list, default: []
  prop :is_loading_periodical_tasks, :boolean, default: false
  prop :is_creating_periodical_task, :boolean, default: false
  prop :editing_periodical_task, :map, default: nil
  prop :periodical_task_title, :string, default: ""
  prop :periodical_task_description, :string, default: ""
  prop :periodical_task_schedule, :string, default: "0 9 * * *"
  prop :periodical_task_executor, :string, default: "claude_code"
  prop :periodical_task_error, :string, default: nil
  prop :cron_validation_error, :string, default: nil
  prop :is_saving_periodical_task, :boolean, default: false

  prop :system_tools, :list, default: []
  prop :is_loading_tools, :boolean, default: false

  @impl Hologram.Component
  def template do
    ~HOLO"""
    {%if @is_open && @board}
      <div class="fixed inset-0 z-50 flex">
        <div class="fixed inset-0 bg-black/40 transition-opacity" $click={action: :close_settings, target: "page"}></div>
        <div class="ml-auto relative w-full max-w-2xl bg-gray-900 border-l border-gray-800 flex flex-col h-full overflow-hidden">
          <div class="flex-shrink-0 px-6 py-4 border-b border-gray-800 flex items-center justify-between">
            <h2 class="text-lg font-semibold text-white">{@board.name} Settings</h2>
            <button
              type="button"
              class="p-2 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
              $click={action: :close_settings, target: "page"}
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="flex border-b border-gray-700">
            <button
              type="button"
              class="px-4 py-2 text-sm transition-colors"
              $click={action: :change_settings_tab, params: %{tab: "general"}, target: "page"}
            >
              <span class={tab_class("general", @active_tab)}>General</span>
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm transition-colors"
              $click={action: :change_settings_tab, params: %{tab: "templates"}, target: "page"}
            >
              <span class={tab_class("templates", @active_tab)}>Templates</span>
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm transition-colors"
              $click={action: :change_settings_tab, params: %{tab: "hooks"}, target: "page"}
            >
              <span class={tab_class("hooks", @active_tab)}>Hooks</span>
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm transition-colors"
              $click={action: :change_settings_tab, params: %{tab: "scheduled"}, target: "page"}
            >
              <span class={tab_class("scheduled", @active_tab)}>Scheduled</span>
            </button>
            <button
              type="button"
              class="px-4 py-2 text-sm transition-colors"
              $click={action: :change_settings_tab, params: %{tab: "system"}, target: "page"}
            >
              <span class={tab_class("system", @active_tab)}>System</span>
            </button>
          </div>

          <div class="flex-1 overflow-y-auto p-6">
            {%if @active_tab == "general"}
              <div class="space-y-6">
                <div>
                  <h3 class="text-sm font-medium text-gray-400 mb-3">Board Information</h3>
                  <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
                    <div class="text-white font-medium">{@board.name}</div>
                    <div class="text-xs text-gray-500 mt-1">Board ID: {@board.id}</div>
                  </div>
                </div>

                <div>
                  <h3 class="text-sm font-medium text-gray-400 mb-3">Repository</h3>
                  {%if @is_loading_repository}
                    <div class="text-gray-400 text-sm">Loading...</div>
                  {%else}
                    {%if @is_editing_repository}
                      <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
                        {%if @repository_error}
                          <div class="p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                            {@repository_error}
                          </div>
                        {/if}

                        <div>
                          <label class="block text-sm text-gray-400 mb-1">Name</label>
                          <input
                            type="text"
                            class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                            placeholder="e.g., My Project"
                            value={@repository_name}
                            $change={action: :update_repository_name, target: "page"}
                          />
                        </div>

                        <div>
                          <label class="block text-sm text-gray-400 mb-1">Path</label>
                          <input
                            type="text"
                            class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white font-mono text-sm placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                            placeholder="/path/to/your/git/repository"
                            value={@repository_path}
                            $change={action: :update_repository_path, target: "page"}
                          />
                          <p class="text-xs text-gray-500 mt-1">Absolute path to the git repository on the server</p>
                        </div>

                        <div>
                          <label class="block text-sm text-gray-400 mb-1">Default Branch</label>
                          <input
                            type="text"
                            class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                            placeholder="main"
                            value={@repository_default_branch}
                            $change={action: :update_repository_default_branch, target: "page"}
                          />
                          <p class="text-xs text-gray-500 mt-1">Base branch for creating new task worktrees</p>
                        </div>

                        <div class="flex gap-2 pt-2">
                          <button
                            type="button"
                            class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
                            $click={action: :cancel_edit_repository, target: "page"}
                          >
                            Cancel
                          </button>
                          <button
                            type="button"
                            class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50"
                            $click={action: :save_repository, target: "page"}
                            disabled={@is_saving_repository}
                          >
                            {%if @is_saving_repository}Saving...{%else}Save{/if}
                          </button>
                        </div>
                      </div>
                    {%else}
                      {%if @repository}
                        <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
                          <div class="flex-1 min-w-0">
                            <span class="font-medium text-white">{@repository.name || @repository.full_name || "Unnamed Repository"}</span>
                            <div class="flex flex-wrap gap-2 mt-2 text-xs text-gray-500">
                              {%if @repository.local_path}
                                <span class="px-2 py-0.5 bg-gray-700 rounded font-mono truncate max-w-full">
                                  {@repository.local_path}
                                </span>
                              {/if}
                              <span class="px-2 py-0.5 bg-gray-700 rounded">
                                Branch: {@repository.default_branch}
                              </span>
                            </div>
                          </div>
                          <div class="mt-3">
                            <button
                              type="button"
                              class="text-sm text-brand-400 hover:text-brand-300 transition-colors"
                              $click={action: :start_edit_repository, target: "page"}
                            >
                              Edit
                            </button>
                          </div>
                        </div>
                      {%else}
                        <div class="p-4 border border-dashed border-gray-700 rounded-lg">
                          <p class="text-gray-500 text-sm mb-3">
                            No repository configured. Link a git repository to enable task worktrees.
                          </p>
                          <button
                            type="button"
                            class="px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors"
                            $click={action: :start_edit_repository, target: "page"}
                          >
                            Configure Repository
                          </button>
                        </div>
                      {/if}
                    {/if}
                  {/if}
                </div>
              </div>
            {/if}

            {%if @active_tab == "templates"}
              <div class="space-y-4">
                <div class="flex justify-between items-center">
                  <h3 class="text-lg font-semibold text-white">Task Templates</h3>
                  {%if !@is_creating_template && !@editing_template}
                    <button
                      type="button"
                      class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors"
                      $click={action: :start_create_template, target: "page"}
                    >
                      Add Template
                    </button>
                  {/if}
                </div>

                <p class="text-sm text-gray-400">
                  Define templates for common task types. When creating a new task, you can select a template to pre-fill the description.
                </p>

                {%if @template_error}
                  <div class="p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                    {@template_error}
                  </div>
                {/if}

                {%if @is_creating_template || @editing_template}
                  <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
                    <h4 class="text-sm font-medium text-gray-300">
                      {%if @is_creating_template}Create Template{%else}Edit Template{/if}
                    </h4>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Name</label>
                      <input
                        type="text"
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                        placeholder="e.g., Feature, Bugfix, Refactor"
                        value={@template_name}
                        $change={action: :update_template_name, target: "page"}
                      />
                    </div>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Description Template</label>
                      <textarea
                        rows="4"
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
                        placeholder="Template text that will be pre-filled..."
                        $change={action: :update_template_description, target: "page"}
                      >{@template_description}</textarea>
                    </div>

                    <div class="flex gap-2">
                      <button
                        type="button"
                        class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
                        $click={action: :cancel_template_edit, target: "page"}
                      >
                        Cancel
                      </button>
                      <button
                        type="button"
                        class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50"
                        $click={action: :save_template, target: "page"}
                        disabled={@is_saving_template}
                      >
                        {%if @is_saving_template}Saving...{%else}Save{/if}
                      </button>
                    </div>
                  </div>
                {/if}

                {%if @is_loading_templates}
                  <div class="text-gray-400 text-sm text-center py-4">Loading templates...</div>
                {%else}
                  {%if length(@task_templates) > 0}
                    <div class="space-y-2">
                      {%for template <- @task_templates}
                        <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg flex items-center justify-between">
                          <div>
                            <div class="font-medium text-white">{template.name}</div>
                            {%if template.description_template}
                              <div class="text-sm text-gray-400 mt-1 truncate max-w-md">{template.description_template}</div>
                            {/if}
                          </div>
                          <div class="flex items-center gap-2">
                            <button
                              type="button"
                              class="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
                              $click={action: :start_edit_template, params: %{template_id: template.id}, target: "page"}
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                              </svg>
                            </button>
                            <button
                              type="button"
                              class="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded-lg transition-colors"
                              $click={action: :delete_template, params: %{template_id: template.id}, target: "page"}
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                              </svg>
                            </button>
                          </div>
                        </div>
                      {/for}
                    </div>
                  {%else}
                    <div class="text-gray-500 text-sm text-center py-8">
                      No templates yet. Create one to speed up task creation.
                    </div>
                  {/if}
                {/if}
              </div>
            {/if}

            {%if @active_tab == "hooks"}
              <div class="space-y-4">
                <div class="flex justify-between items-center">
                  <h3 class="text-lg font-semibold text-white">Hooks</h3>
                  {%if !@is_creating_hook && !@editing_hook}
                    <button
                      type="button"
                      class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors"
                      $click={action: :start_create_hook, target: "page"}
                    >
                      Add Hook
                    </button>
                  {/if}
                </div>

                <p class="text-sm text-gray-400">
                  Hooks are scripts or AI agents that can be triggered when tasks move between columns.
                </p>

                {%if @hook_error}
                  <div class="p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                    {@hook_error}
                  </div>
                {/if}

                {%if @is_creating_hook || @editing_hook}
                  <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
                    <h4 class="text-sm font-medium text-gray-300">
                      {%if @is_creating_hook}Create Hook{%else}Edit Hook{/if}
                    </h4>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Name</label>
                      <input
                        type="text"
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                        placeholder="e.g., Run Tests, Deploy to Staging"
                        value={@hook_name}
                        $change={action: :update_hook_name, target: "page"}
                      />
                    </div>

                    <div>
                      <label class="block text-sm text-gray-400 mb-2">Hook Type</label>
                      <div class="flex gap-4">
                        <label class="flex items-center gap-2 cursor-pointer">
                          <input
                            type="radio"
                            name="hook_kind"
                            value="script"
                            checked={@hook_kind == "script"}
                            $change={action: :update_hook_kind, target: "page"}
                            class="text-brand-500 focus:ring-brand-500"
                          />
                          <span class="text-sm text-gray-300">Script</span>
                        </label>
                        <label class="flex items-center gap-2 cursor-pointer">
                          <input
                            type="radio"
                            name="hook_kind"
                            value="agent"
                            checked={@hook_kind == "agent"}
                            $change={action: :update_hook_kind, target: "page"}
                            class="text-brand-500 focus:ring-brand-500"
                          />
                          <span class="text-sm text-gray-300">AI Agent</span>
                        </label>
                      </div>
                    </div>

                    {%if @hook_kind == "script"}
                      <div>
                        <label class="block text-sm text-gray-400 mb-1">Command</label>
                        <input
                          type="text"
                          class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white font-mono text-sm placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                          placeholder="e.g., ./scripts/run-tests.sh"
                          value={@hook_command}
                          $change={action: :update_hook_command, target: "page"}
                        />
                      </div>
                    {%else}
                      <div>
                        <label class="block text-sm text-gray-400 mb-1">Agent Executor</label>
                        <select
                          class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500"
                          $change={action: :update_hook_agent_executor, target: "page"}
                        >
                          <option value="claude_code" selected={@hook_agent_executor == "claude_code"}>Claude Code</option>
                          <option value="gemini_cli" selected={@hook_agent_executor == "gemini_cli"}>Gemini CLI</option>
                          <option value="codex" selected={@hook_agent_executor == "codex"}>Codex</option>
                          <option value="opencode" selected={@hook_agent_executor == "opencode"}>OpenCode</option>
                          <option value="cursor_agent" selected={@hook_agent_executor == "cursor_agent"}>Cursor Agent</option>
                        </select>
                      </div>

                      <div>
                        <label class="block text-sm text-gray-400 mb-1">Prompt</label>
                        <textarea
                          rows="4"
                          class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
                          placeholder="Instructions for the AI agent..."
                          $change={action: :update_hook_agent_prompt, target: "page"}
                        >{@hook_agent_prompt}</textarea>
                      </div>

                      <div>
                        <label class="flex items-center gap-2 cursor-pointer">
                          <input
                            type="checkbox"
                            checked={@hook_agent_auto_approve}
                            $change={action: :toggle_hook_auto_approve, target: "page"}
                            class="text-brand-500 focus:ring-brand-500 rounded"
                          />
                          <span class="text-sm text-gray-300">Auto-approve agent actions</span>
                        </label>
                      </div>
                    {/if}

                    <div class="flex gap-2">
                      <button
                        type="button"
                        class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
                        $click={action: :cancel_hook_edit, target: "page"}
                      >
                        Cancel
                      </button>
                      <button
                        type="button"
                        class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50"
                        $click={action: :save_hook, target: "page"}
                        disabled={@is_saving_hook}
                      >
                        {%if @is_saving_hook}Saving...{%else}Save{/if}
                      </button>
                    </div>
                  </div>
                {/if}

                {%if @is_loading_hooks}
                  <div class="text-gray-400 text-sm text-center py-4">Loading hooks...</div>
                {%else}
                  {%if length(@hooks) > 0}
                    <div class="space-y-2">
                      {%for hook <- @hooks}
                        <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg flex items-center justify-between">
                          <div class="flex items-center gap-3">
                            {%if hook["is_system"]}
                              <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                              </svg>
                            {%else}
                              {%if hook["hook_kind"] == "agent"}
                                <svg class="w-4 h-4 text-purple-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                                </svg>
                              {%else}
                                <svg class="w-4 h-4 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                              {/if}
                            {/if}
                            <div>
                              <div class="font-medium text-white flex items-center gap-2">
                                {hook["name"]}
                                {%if hook["is_system"]}
                                  <span class="text-xs px-1.5 py-0.5 bg-gray-700 text-gray-400 rounded">System</span>
                                {/if}
                              </div>
                              {%if hook["hook_kind"] == "agent" && hook["agent_prompt"]}
                                <div class="text-xs text-gray-500 mt-0.5 truncate max-w-md">{truncate(hook["agent_prompt"], 100)}</div>
                              {/if}
                              {%if hook["hook_kind"] == "script" && hook["command"]}
                                <div class="text-xs text-gray-500 font-mono mt-0.5">{hook["command"]}</div>
                              {/if}
                            </div>
                          </div>
                          {%if !hook["is_system"]}
                            <div class="flex items-center gap-2">
                              <button
                                type="button"
                                class="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
                                $click={action: :start_edit_hook, params: %{hook_id: hook["id"]}, target: "page"}
                              >
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                </svg>
                              </button>
                              <button
                                type="button"
                                class="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded-lg transition-colors"
                                $click={action: :delete_hook, params: %{hook_id: hook["id"]}, target: "page"}
                              >
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                </svg>
                              </button>
                            </div>
                          {/if}
                        </div>
                      {/for}
                    </div>
                  {%else}
                    <div class="text-gray-500 text-sm text-center py-8">
                      No hooks configured. Add a hook to automate workflows.
                    </div>
                  {/if}
                {/if}
              </div>
            {/if}

            {%if @active_tab == "scheduled"}
              <div class="space-y-4">
                <div class="flex justify-between items-center">
                  <h3 class="text-lg font-semibold text-white">Scheduled Tasks</h3>
                  {%if !@is_creating_periodical_task && !@editing_periodical_task}
                    <button
                      type="button"
                      class="px-3 py-1.5 bg-brand-600 hover:bg-brand-700 text-white text-sm font-medium rounded-lg transition-colors"
                      $click={action: :start_create_periodical_task, target: "page"}
                    >
                      Add Scheduled Task
                    </button>
                  {/if}
                </div>

                <p class="text-sm text-gray-400">
                  Scheduled tasks run automatically on a cron schedule using AI agents.
                </p>

                {%if @periodical_task_error}
                  <div class="p-3 bg-red-900/50 border border-red-800 rounded-lg text-red-200 text-sm">
                    {@periodical_task_error}
                  </div>
                {/if}

                {%if @is_creating_periodical_task || @editing_periodical_task}
                  <div class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4">
                    <h4 class="text-sm font-medium text-gray-300">
                      {%if @is_creating_periodical_task}Create Scheduled Task{%else}Edit Scheduled Task{/if}
                    </h4>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Title</label>
                      <input
                        type="text"
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
                        placeholder="e.g., Daily Code Review"
                        value={@periodical_task_title}
                        $change={action: :update_periodical_task_title, target: "page"}
                      />
                    </div>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Description</label>
                      <textarea
                        rows="3"
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500 resize-none"
                        placeholder="Task description and instructions..."
                        $change={action: :update_periodical_task_description, target: "page"}
                      >{@periodical_task_description}</textarea>
                    </div>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Schedule (Cron)</label>
                      <input
                        type="text"
                        class={cron_input_class(@cron_validation_error)}
                        placeholder="0 9 * * *"
                        value={@periodical_task_schedule}
                        $change={action: :update_periodical_task_schedule, target: "page"}
                      />
                      {%if @cron_validation_error}
                        <p class="text-xs text-red-400 mt-1">{@cron_validation_error}</p>
                      {%else}
                        <p class="text-xs text-gray-500 mt-1">Standard cron format: minute hour day month weekday</p>
                      {/if}
                    </div>

                    <div>
                      <label class="block text-sm text-gray-400 mb-1">Executor</label>
                      <select
                        class="w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-brand-500"
                        $change={action: :update_periodical_task_executor, target: "page"}
                      >
                        <option value="claude_code" selected={@periodical_task_executor == "claude_code"}>Claude Code</option>
                        <option value="gemini_cli" selected={@periodical_task_executor == "gemini_cli"}>Gemini CLI</option>
                        <option value="codex" selected={@periodical_task_executor == "codex"}>Codex</option>
                        <option value="opencode" selected={@periodical_task_executor == "opencode"}>OpenCode</option>
                        <option value="cursor_agent" selected={@periodical_task_executor == "cursor_agent"}>Cursor Agent</option>
                      </select>
                    </div>

                    <div class="flex gap-2">
                      <button
                        type="button"
                        class="flex-1 px-4 py-2 text-gray-300 hover:text-white bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors"
                        $click={action: :cancel_periodical_task_edit, target: "page"}
                      >
                        Cancel
                      </button>
                      <button
                        type="button"
                        class="flex-1 px-4 py-2 bg-brand-600 hover:bg-brand-700 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        $click={action: :save_periodical_task, target: "page"}
                        disabled={@is_saving_periodical_task || @cron_validation_error != nil}
                      >
                        {%if @is_saving_periodical_task}Saving...{%else}Save{/if}
                      </button>
                    </div>
                  </div>
                {/if}

                {%if @is_loading_periodical_tasks}
                  <div class="text-gray-400 text-sm text-center py-4">Loading scheduled tasks...</div>
                {%else}
                  {%if length(@periodical_tasks) > 0}
                    <div class="space-y-2">
                      {%for task <- @periodical_tasks}
                        <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
                          <div class="flex items-center justify-between">
                            <div class="flex items-center gap-3">
                              <div class={periodical_task_status_class(task.enabled)}></div>
                              <div>
                                <div class="font-medium text-white">{task.title}</div>
                                <div class="flex items-center gap-3 mt-1 text-xs text-gray-500">
                                  <span class="font-mono">{task.schedule}</span>
                                  <span>·</span>
                                  <span>{executor_label(task.executor)}</span>
                                  {%if task.execution_count > 0}
                                    <span>·</span>
                                    <span>Runs: {task.execution_count}</span>
                                  {/if}
                                </div>
                              </div>
                            </div>
                            <div class="flex items-center gap-2">
                              <button
                                type="button"
                                class={toggle_task_button_class(task.enabled)}
                                $click={action: :toggle_periodical_task, params: %{task_id: task.id, enabled: !task.enabled}, target: "page"}
                                title={toggle_task_title(task.enabled)}
                              >
                                {%if task.enabled}
                                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                                  </svg>
                                {%else}
                                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                  </svg>
                                {/if}
                              </button>
                              <button
                                type="button"
                                class="p-2 text-gray-400 hover:text-white hover:bg-gray-700 rounded-lg transition-colors"
                                $click={action: :start_edit_periodical_task, params: %{task_id: task.id}, target: "page"}
                              >
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                                </svg>
                              </button>
                              <button
                                type="button"
                                class="p-2 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded-lg transition-colors"
                                $click={action: :delete_periodical_task, params: %{task_id: task.id}, target: "page"}
                              >
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                                </svg>
                              </button>
                            </div>
                          </div>
                        </div>
                      {/for}
                    </div>
                  {%else}
                    <div class="text-gray-500 text-sm text-center py-8">
                      No scheduled tasks. Create one to automate recurring work.
                    </div>
                  {/if}
                {/if}
              </div>
            {/if}

            {%if @active_tab == "system"}
              <div class="space-y-6">
                <div>
                  <h3 class="text-sm font-medium text-gray-400 mb-1">System Tools Status</h3>
                  <p class="text-xs text-gray-500">
                    These CLI tools provide additional functionality. Install missing tools to unlock features.
                  </p>
                </div>

                {%if @is_loading_tools}
                  <div class="text-center py-8">
                    <div class="animate-spin w-6 h-6 border-2 border-brand-500 border-t-transparent rounded-full mx-auto"></div>
                    <p class="text-sm text-gray-400 mt-2">Loading tools...</p>
                  </div>
                {%else}
                  {%if length(@system_tools) > 0}
                    <div class="space-y-6">
                      <div class="space-y-2">
                        <h4 class="text-sm font-medium text-gray-400">Core Tools</h4>
                        {%for tool <- filter_tools(@system_tools, "core")}
                          <div class={tool_item_class(tool.available)}>
                            <div class="flex items-center gap-3">
                              <div class={tool_status_dot_class(tool.available)}></div>
                              <div>
                                <div class="flex items-center gap-2">
                                  <span class="font-medium text-white">{tool.display_name}</span>
                                  {%if tool.version}
                                    <span class="text-xs text-gray-500">v{tool.version}</span>
                                  {/if}
                                </div>
                                {%if tool.description}
                                  <p class="text-xs text-gray-400 mt-0.5">{tool.description}</p>
                                {/if}
                              </div>
                            </div>
                            <span class={tool_badge_class(tool.available)}>
                              {%if tool.available}Available{%else}Not Found{/if}
                            </span>
                          </div>
                        {/for}
                      </div>

                      <div class="space-y-2">
                        <h4 class="text-sm font-medium text-gray-400">Optional Tools</h4>
                        {%for tool <- filter_tools(@system_tools, "optional")}
                          <div class={tool_item_class(tool.available)}>
                            <div class="flex items-center gap-3">
                              <div class={tool_status_dot_class(tool.available)}></div>
                              <div>
                                <div class="flex items-center gap-2">
                                  <span class="font-medium text-white">{tool.display_name}</span>
                                  {%if tool.version}
                                    <span class="text-xs text-gray-500">v{tool.version}</span>
                                  {/if}
                                </div>
                                {%if tool.description}
                                  <p class="text-xs text-gray-400 mt-0.5">{tool.description}</p>
                                {/if}
                              </div>
                            </div>
                            <span class={tool_badge_class(tool.available)}>
                              {%if tool.available}Available{%else}Not Found{/if}
                            </span>
                          </div>
                        {/for}
                      </div>
                    </div>
                  {%else}
                    <div class="text-gray-500 text-sm text-center py-4">
                      No tools detected.
                    </div>
                  {/if}
                {/if}
              </div>
            {/if}
          </div>
        </div>
      </div>
    {/if}
    """
  end

  defp tab_class(tab, active_tab) do
    if tab == active_tab do
      "border-b-2 border-brand-500 text-brand-400 pb-2"
    else
      "border-b-2 border-transparent text-gray-400 pb-2"
    end
  end

  defp truncate(nil, _max), do: ""
  defp truncate(str, max) when byte_size(str) <= max, do: str
  defp truncate(str, max), do: String.slice(str, 0, max) <> "..."

  defp periodical_task_status_class(true), do: "w-2 h-2 rounded-full bg-green-500"
  defp periodical_task_status_class(false), do: "w-2 h-2 rounded-full bg-gray-500"

  defp toggle_task_button_class(true), do: "p-2 text-yellow-400 hover:text-yellow-300 hover:bg-gray-700 rounded-lg transition-colors"
  defp toggle_task_button_class(false), do: "p-2 text-green-400 hover:text-green-300 hover:bg-gray-700 rounded-lg transition-colors"

  defp toggle_task_title(true), do: "Pause"
  defp toggle_task_title(false), do: "Resume"

  defp executor_label("claude_code"), do: "Claude Code"
  defp executor_label("gemini_cli"), do: "Gemini CLI"
  defp executor_label("codex"), do: "Codex"
  defp executor_label("opencode"), do: "OpenCode"
  defp executor_label("cursor_agent"), do: "Cursor Agent"
  defp executor_label(executor) when is_atom(executor), do: executor_label(to_string(executor))
  defp executor_label(_), do: "Unknown"

  defp filter_tools(tools, category) do
    Enum.filter(tools, fn tool -> tool.category == category end)
  end

  defp tool_item_class(true), do: "flex items-center justify-between p-3 rounded-lg border bg-gray-800/50 border-gray-700"
  defp tool_item_class(false), do: "flex items-center justify-between p-3 rounded-lg border bg-gray-800/30 border-gray-700/50 opacity-60"

  defp tool_status_dot_class(true), do: "w-2 h-2 rounded-full bg-green-500"
  defp tool_status_dot_class(false), do: "w-2 h-2 rounded-full bg-gray-500"

  defp tool_badge_class(true), do: "text-xs px-2 py-0.5 rounded bg-green-900/50 text-green-400"
  defp tool_badge_class(false), do: "text-xs px-2 py-0.5 rounded bg-gray-700/50 text-gray-500"

  defp cron_input_class(nil) do
    "w-full px-3 py-2 bg-gray-800 border border-gray-600 rounded-lg text-white font-mono text-sm placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-brand-500"
  end

  defp cron_input_class(_error) do
    "w-full px-3 py-2 bg-gray-800 border border-red-500 rounded-lg text-white font-mono text-sm placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-red-500"
  end
end
