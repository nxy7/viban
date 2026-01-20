defmodule VibanWeb.Live.BoardLive.Components.BoardSettings do
  @moduledoc """
  Board settings side panel component for the board view.
  Provides tabs for General, Templates, Hooks, Column Hooks, Scheduled, and System settings.
  """

  use Phoenix.Component

  import VibanWeb.CoreComponents

  @tabs [
    {:general, "General"},
    {:templates, "Templates"},
    {:hooks, "Hooks"},
    {:columns, "Column Hooks"},
    {:scheduled, "Scheduled"},
    {:system, "System"}
  ]

  # ============================================================================
  # Side Panel
  # ============================================================================

  attr :show, :boolean, required: true
  attr :board, :map, required: true
  attr :active_tab, :atom, default: :general
  attr :columns, :list, default: []
  attr :repository, :map, default: nil
  attr :repo_form, :any, default: nil
  attr :editing_repo, :boolean, default: false
  attr :templates, :list, default: []
  attr :editing_template, :any, default: nil
  attr :template_form, :any, default: nil
  attr :hooks, :list, default: []
  attr :system_hooks, :list, default: []
  attr :editing_hook, :any, default: nil
  attr :hook_form, :any, default: nil
  attr :hook_kind, :atom, default: :script
  attr :periodical_tasks, :list, default: []
  attr :editing_periodical_task, :any, default: nil
  attr :periodical_task_form, :any, default: nil
  attr :system_tools, :list, default: []

  @executors [
    {"claude_code", "Claude Code"},
    {"gemini_cli", "Gemini CLI"},
    {"codex", "Codex"},
    {"opencode", "OpenCode"},
    {"cursor_agent", "Cursor Agent"}
  ]

  def board_settings_panel(assigns) do
    assigns = assign(assigns, :tabs, @tabs)

    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-sm"
      phx-click="hide_settings"
    >
      <div
        class="bg-gray-900 border-l border-gray-800 w-full max-w-lg h-full shadow-2xl flex flex-col animate-slide-in-right"
        phx-click-away="hide_settings"
        phx-window-keydown="hide_settings"
        phx-key="Escape"
      >
        <div class="flex-shrink-0 bg-gray-900 border-b border-gray-800 px-6 py-4 flex items-center justify-between">
          <h2 class="text-lg font-semibold text-white">{@board.name} Settings</h2>
          <button
            phx-click="hide_settings"
            class="p-1 text-gray-400 hover:text-white hover:bg-gray-800 rounded-lg transition-colors"
          >
            <.icon name="hero-x-mark" class="w-5 h-5" />
          </button>
        </div>

        <div class="flex-1 min-h-0 flex flex-col overflow-y-auto px-6 py-4">
          <.settings_tabs tabs={@tabs} active_tab={@active_tab} />

          <div class="space-y-6 mt-4">
            <.general_tab
              :if={@active_tab == :general}
              board={@board}
              repository={@repository}
              repo_form={@repo_form}
              editing_repo={@editing_repo}
            />
            <.templates_tab
              :if={@active_tab == :templates}
              templates={@templates}
              editing_template={@editing_template}
              template_form={@template_form}
            />
            <.hooks_tab
              :if={@active_tab == :hooks}
              hooks={@hooks}
              system_hooks={@system_hooks}
              editing_hook={@editing_hook}
              hook_form={@hook_form}
              hook_kind={@hook_kind}
            />
            <.columns_tab :if={@active_tab == :columns} columns={@columns} />
            <.scheduled_tab
              :if={@active_tab == :scheduled}
              periodical_tasks={@periodical_tasks}
              editing_periodical_task={@editing_periodical_task}
              periodical_task_form={@periodical_task_form}
            />
            <.system_tab :if={@active_tab == :system} system_tools={@system_tools} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Settings Tabs Navigation
  # ============================================================================

  attr :tabs, :list, required: true
  attr :active_tab, :atom, required: true

  defp settings_tabs(assigns) do
    ~H"""
    <div class="flex border-b border-gray-700 -mx-6 px-6 overflow-x-auto">
      <button
        :for={{tab_id, tab_label} <- @tabs}
        phx-click="settings_tab"
        phx-value-tab={tab_id}
        class="px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors hover:text-white"
      >
        <span class={[
          "border-b-2 pb-1 transition-colors",
          @active_tab == tab_id && "border-brand-500 text-brand-400",
          @active_tab != tab_id && "border-transparent text-gray-400"
        ]}>
          {tab_label}
        </span>
      </button>
    </div>
    """
  end

  # ============================================================================
  # General Tab
  # ============================================================================

  attr :board, :map, required: true
  attr :repository, :map, default: nil
  attr :repo_form, :any, default: nil
  attr :editing_repo, :boolean, default: false

  defp general_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-medium text-gray-400 mb-3">Board Information</h3>
        <div class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
          <div class="text-white font-medium">{@board.name}</div>
          <div class="text-xs text-gray-500 mt-1">
            Board ID: {@board.id}
          </div>
        </div>
      </div>

      <div>
        <h3 class="text-sm font-medium text-gray-400 mb-3">Repository</h3>
        <.repository_config
          repository={@repository}
          repo_form={@repo_form}
          editing_repo={@editing_repo}
        />
      </div>
    </div>
    """
  end

  # ============================================================================
  # Repository Config
  # ============================================================================

  attr :repository, :map, default: nil
  attr :repo_form, :any, default: nil
  attr :editing_repo, :boolean, default: false

  defp repository_config(assigns) do
    ~H"""
    <div class="space-y-3">
      <div
        :if={@editing_repo && @repo_form}
        class="p-4 bg-gray-800 border border-gray-700 rounded-lg space-y-4"
      >
        <.form for={@repo_form} phx-submit="save_repository" class="space-y-4">
          <.input field={@repo_form[:name]} label="Name" placeholder="e.g., My Project" />
          <div>
            <.input
              field={@repo_form[:local_path]}
              label="Path"
              placeholder="/path/to/your/git/repository"
            />
            <p class="text-xs text-gray-500 mt-1">
              Absolute path to the git repository on the server
            </p>
          </div>
          <div>
            <.input field={@repo_form[:default_branch]} label="Default Branch" placeholder="main" />
            <p class="text-xs text-gray-500 mt-1">
              Base branch for creating new task worktrees
            </p>
          </div>
          <div class="flex gap-2 pt-2">
            <.button type="button" variant="ghost" phx-click="cancel_edit_repo" class="flex-1">
              Cancel
            </.button>
            <.button type="submit" class="flex-1">
              Save
            </.button>
          </div>
        </.form>
      </div>

      <div
        :if={!@editing_repo && @repository}
        class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg"
      >
        <div class="flex-1 min-w-0">
          <span class="font-medium text-white">
            {@repository.full_name || @repository.name || "Unnamed Repository"}
          </span>
          <div class="flex flex-wrap gap-2 mt-2 text-xs text-gray-500">
            <span
              :if={@repository.local_path}
              class="px-2 py-0.5 bg-gray-700 rounded font-mono truncate max-w-full"
              title={@repository.local_path}
            >
              {@repository.local_path}
            </span>
            <span class="px-2 py-0.5 bg-gray-700 rounded">
              Branch: {@repository.default_branch || "main"}
            </span>
          </div>
        </div>
      </div>

      <div
        :if={!@editing_repo && !@repository}
        class="p-4 bg-gray-800/50 border border-dashed border-gray-700 rounded-lg"
      >
        <p class="text-gray-500 text-sm mb-3">
          No repository configured. Link a git repository to enable task worktrees.
        </p>
        <.button phx-click="edit_repo" variant="secondary">
          Configure Repository
        </.button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Templates Tab
  # ============================================================================

  attr :templates, :list, default: []
  attr :editing_template, :any, default: nil
  attr :template_form, :any, default: nil

  defp templates_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <p class="text-sm text-gray-400">
          Create templates for common task types.
        </p>
        <button
          :if={!@editing_template}
          phx-click="new_template"
          class="px-3 py-1.5 text-sm font-medium text-white bg-brand-600 hover:bg-brand-500 rounded-md transition-colors"
        >
          <.icon name="hero-plus" class="w-4 h-4 mr-1 inline" /> New Template
        </button>
      </div>

      <div
        :if={@editing_template && @template_form}
        class="p-4 bg-gray-800 border border-gray-700 rounded-lg"
      >
        <.form for={@template_form} phx-submit="save_template" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Template Name</label>
            <.input field={@template_form[:name]} placeholder="e.g., Feature, Bugfix, Research" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Description Template</label>
            <.input
              field={@template_form[:description_template]}
              type="textarea"
              rows="6"
              placeholder="## Summary&#10;&#10;## Requirements&#10;&#10;## Acceptance Criteria"
              class="font-mono text-sm"
            />
            <p class="text-xs text-gray-500 mt-1">
              Markdown template for new tasks using this template
            </p>
          </div>
          <div class="flex gap-2 pt-2">
            <.button type="button" variant="ghost" phx-click="cancel_edit_template" class="flex-1">
              Cancel
            </.button>
            <.button type="submit" class="flex-1">
              Save Template
            </.button>
          </div>
        </.form>
      </div>

      <div
        :if={@templates == [] && !@editing_template}
        class="text-center py-8 text-gray-500 border border-dashed border-gray-700 rounded-lg"
      >
        <.icon name="hero-document-duplicate" class="w-8 h-8 mx-auto mb-2 opacity-50" />
        <p class="text-sm">No templates yet</p>
        <p class="text-xs mt-1">Click "New Template" to create one</p>
      </div>

      <div :if={@templates != [] && !@editing_template} class="space-y-2">
        <div
          :for={template <- @templates}
          class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg hover:border-gray-600 transition-colors"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <h4 class="font-medium text-white">{template.name}</h4>
              <p
                :if={template.description_template}
                class="text-xs text-gray-500 mt-1 font-mono truncate"
              >
                {String.slice(template.description_template || "", 0, 60)}<span :if={
                  String.length(template.description_template || "") > 60
                }>...</span>
              </p>
            </div>
            <div class="flex items-center gap-1 ml-2">
              <button
                phx-click="edit_template"
                phx-value-id={template.id}
                class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
              >
                <.icon name="hero-pencil" class="w-4 h-4" />
              </button>
              <button
                phx-click="delete_template"
                phx-value-id={template.id}
                data-confirm="Delete this template?"
                class="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded transition-colors"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Hooks Tab
  # ============================================================================

  @agent_executors [
    {"claude_code", "Claude Code"},
    {"gemini_cli", "Gemini CLI"},
    {"codex", "Codex"},
    {"opencode", "OpenCode"},
    {"cursor_agent", "Cursor Agent"}
  ]

  attr :hooks, :list, default: []
  attr :system_hooks, :list, default: []
  attr :editing_hook, :any, default: nil
  attr :hook_form, :any, default: nil
  attr :hook_kind, :atom, default: :script

  defp hooks_tab(assigns) do
    assigns = assign(assigns, :agent_executors, @agent_executors)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <p class="text-sm text-gray-400">
          Configure automation hooks that run when tasks enter columns.
        </p>
        <button
          :if={!@editing_hook}
          phx-click="new_hook"
          class="px-3 py-1.5 text-sm font-medium text-white bg-brand-600 hover:bg-brand-500 rounded-md transition-colors"
        >
          <.icon name="hero-plus" class="w-4 h-4 mr-1 inline" /> New Hook
        </button>
      </div>

      <div :if={@editing_hook && @hook_form} class="p-4 bg-gray-800 border border-gray-700 rounded-lg">
        <.form for={@hook_form} phx-submit="save_hook" class="space-y-4">
          <div :if={@editing_hook == :new}>
            <label class="block text-sm font-medium text-gray-300 mb-2">Hook Type</label>
            <div class="flex gap-2">
              <button
                type="button"
                phx-click="set_hook_kind"
                phx-value-kind="script"
                class={[
                  "flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors",
                  @hook_kind == :script && "bg-brand-600 text-white",
                  @hook_kind != :script && "bg-gray-700 text-gray-300 hover:bg-gray-600"
                ]}
              >
                <.icon name="hero-command-line" class="w-4 h-4 mr-1 inline" /> Script
              </button>
              <button
                type="button"
                phx-click="set_hook_kind"
                phx-value-kind="agent"
                class={[
                  "flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors",
                  @hook_kind == :agent && "bg-brand-600 text-white",
                  @hook_kind != :agent && "bg-gray-700 text-gray-300 hover:bg-gray-600"
                ]}
              >
                <.icon name="hero-sparkles" class="w-4 h-4 mr-1 inline" /> AI Agent
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Hook Name</label>
            <.input field={@hook_form[:name]} placeholder="e.g., Run tests, Deploy preview" />
          </div>

          <div :if={@hook_kind == :script}>
            <label class="block text-sm font-medium text-gray-300 mb-1">Command</label>
            <.input
              field={@hook_form[:command]}
              type="textarea"
              rows="3"
              placeholder="#!/bin/bash&#10;npm test"
              class="font-mono text-sm"
            />
            <p class="text-xs text-gray-500 mt-1">Shell command or script with shebang</p>
          </div>

          <div :if={@hook_kind == :agent} class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Executor</label>
              <select
                name="agent_executor"
                class="w-full bg-gray-700 border-gray-600 rounded-md text-white text-sm"
              >
                <option
                  :for={{value, label} <- @agent_executors}
                  value={value}
                  selected={@hook_form[:agent_executor].value == value}
                >
                  {label}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">Agent Prompt</label>
              <.input
                field={@hook_form[:agent_prompt]}
                type="textarea"
                rows="4"
                placeholder="Describe what the AI agent should do when this hook runs..."
                class="font-mono text-sm"
              />
            </div>
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                name="agent_auto_approve"
                value="true"
                checked={@hook_form[:agent_auto_approve].value}
                class="h-4 w-4 rounded border-gray-600 bg-gray-700 text-brand-600 focus:ring-brand-500"
              />
              <label class="text-sm text-gray-300">Auto-approve tool calls</label>
            </div>
          </div>

          <div class="flex items-center gap-4 pt-2 border-t border-gray-700">
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                name="default_execute_once"
                value="true"
                checked={@hook_form[:default_execute_once].value}
                class="h-4 w-4 rounded border-gray-600 bg-gray-700 text-brand-600 focus:ring-brand-500"
              />
              <label class="text-sm text-gray-300">Execute once by default</label>
            </div>
            <div class="flex items-center gap-2">
              <input
                type="checkbox"
                name="default_transparent"
                value="true"
                checked={@hook_form[:default_transparent].value}
                class="h-4 w-4 rounded border-gray-600 bg-gray-700 text-brand-600 focus:ring-brand-500"
              />
              <label class="text-sm text-gray-300">Transparent by default</label>
            </div>
          </div>

          <div class="flex gap-2 pt-2">
            <.button type="button" variant="ghost" phx-click="cancel_edit_hook" class="flex-1">
              Cancel
            </.button>
            <.button type="submit" class="flex-1">
              Save Hook
            </.button>
          </div>
        </.form>
      </div>

      <div :if={@system_hooks != [] && !@editing_hook} class="space-y-2">
        <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wider">System Hooks</h4>
        <div
          :for={hook <- @system_hooks}
          class="p-3 bg-purple-900/20 border border-purple-500/30 rounded-lg"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="px-1.5 py-0.5 text-xs font-medium bg-purple-600 text-white rounded">
                System
              </span>
              <span class="font-medium text-white">{hook.name}</span>
            </div>
          </div>
          <p :if={hook.description} class="text-xs text-gray-400 mt-1">{hook.description}</p>
        </div>
      </div>

      <div :if={!@editing_hook} class="space-y-2">
        <h4 class="text-xs font-medium text-gray-500 uppercase tracking-wider">Custom Hooks</h4>
        <div
          :if={@hooks == []}
          class="text-center py-6 text-gray-500 border border-dashed border-gray-700 rounded-lg"
        >
          <.icon name="hero-bolt" class="w-6 h-6 mx-auto mb-2 opacity-50" />
          <p class="text-sm">No custom hooks yet</p>
          <p class="text-xs mt-1">Click "New Hook" to create one</p>
        </div>
        <div
          :for={hook <- @hooks}
          class="p-3 bg-gray-800/50 border border-gray-700 rounded-lg hover:border-gray-600 transition-colors"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class={[
                  "px-1.5 py-0.5 text-xs font-medium rounded",
                  hook.hook_kind == :script && "bg-gray-600 text-gray-200",
                  hook.hook_kind == :agent && "bg-blue-600 text-white"
                ]}>
                  {if hook.hook_kind == :script, do: "Script", else: "Agent"}
                </span>
                <span class="font-medium text-white">{hook.name}</span>
              </div>
              <p
                :if={hook.hook_kind == :script && hook.command}
                class="text-xs text-gray-500 mt-1 font-mono truncate"
              >
                {String.slice(hook.command || "", 0, 50)}<span :if={
                  String.length(hook.command || "") > 50
                }>...</span>
              </p>
              <p
                :if={hook.hook_kind == :agent && hook.agent_prompt}
                class="text-xs text-gray-500 mt-1 truncate"
              >
                {String.slice(hook.agent_prompt || "", 0, 50)}<span :if={
                  String.length(hook.agent_prompt || "") > 50
                }>...</span>
              </p>
            </div>
            <div class="flex items-center gap-1 ml-2">
              <button
                phx-click="edit_hook"
                phx-value-id={hook.id}
                class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
              >
                <.icon name="hero-pencil" class="w-4 h-4" />
              </button>
              <button
                phx-click="delete_hook"
                phx-value-id={hook.id}
                data-confirm="Delete this hook?"
                class="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded transition-colors"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Column Hooks Tab
  # ============================================================================

  attr :columns, :list, default: []

  defp columns_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-gray-400">
        Configure which hooks run when tasks enter each column.
      </p>
      <div :if={@columns == []} class="text-gray-500 text-sm text-center py-4">
        No columns found for this board.
      </div>
      <div :for={column <- @columns} class="p-4 bg-gray-800/50 border border-gray-700 rounded-lg">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded-full" style={"background-color: #{column.color || "#6b7280"}"}>
            </div>
            <span class="font-medium text-white">{column.name}</span>
          </div>
          <span class="text-xs text-gray-500">No hooks configured</span>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Scheduled Tab
  # ============================================================================

  attr :periodical_tasks, :list, default: []
  attr :editing_periodical_task, :any, default: nil
  attr :periodical_task_form, :any, default: nil

  defp scheduled_tab(assigns) do
    assigns = assign(assigns, :executors, @executors)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <p class="text-sm text-gray-400">
          Configure tasks that run automatically on a schedule.
        </p>
        <button
          :if={!@editing_periodical_task}
          phx-click="new_periodical_task"
          class="px-3 py-1.5 text-sm font-medium text-white bg-brand-600 hover:bg-brand-500 rounded-md transition-colors"
        >
          <.icon name="hero-plus" class="w-4 h-4 mr-1 inline" /> New Schedule
        </button>
      </div>

      <div
        :if={@editing_periodical_task && @periodical_task_form}
        class="p-4 bg-gray-800 border border-gray-700 rounded-lg"
      >
        <.form for={@periodical_task_form} phx-submit="save_periodical_task" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Title</label>
            <.input field={@periodical_task_form[:title]} placeholder="e.g., Daily Code Review" />
            <p class="text-xs text-gray-500 mt-1">
              Tasks will be created as "#1 Title", "#2 Title", etc.
            </p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Description</label>
            <.input
              field={@periodical_task_form[:description]}
              type="textarea"
              rows="4"
              placeholder="Describe what this scheduled task should do..."
              class="font-mono text-sm"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Schedule (cron)</label>
            <.input
              field={@periodical_task_form[:schedule]}
              placeholder="0 9 * * 1-5"
              class="font-mono"
            />
            <p class="text-xs text-gray-500 mt-1">
              Cron format: minute hour day-of-month month day-of-week
            </p>
            <div class="mt-2 flex flex-wrap gap-1">
              <button
                type="button"
                phx-click="set_cron_preset"
                phx-value-cron="0 9 * * 1-5"
                class="px-2 py-0.5 text-xs bg-gray-700 text-gray-300 hover:bg-gray-600 rounded"
              >
                Weekdays 9am
              </button>
              <button
                type="button"
                phx-click="set_cron_preset"
                phx-value-cron="0 0 * * *"
                class="px-2 py-0.5 text-xs bg-gray-700 text-gray-300 hover:bg-gray-600 rounded"
              >
                Daily midnight
              </button>
              <button
                type="button"
                phx-click="set_cron_preset"
                phx-value-cron="0 0 * * 6"
                class="px-2 py-0.5 text-xs bg-gray-700 text-gray-300 hover:bg-gray-600 rounded"
              >
                Weekly Sat
              </button>
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-300 mb-1">Executor</label>
            <select
              name="executor"
              class="w-full bg-gray-700 border-gray-600 rounded-md text-white text-sm"
            >
              <option
                :for={{value, label} <- @executors}
                value={value}
                selected={to_string(@periodical_task_form[:executor].value) == value}
              >
                {label}
              </option>
            </select>
          </div>
          <div class="flex gap-2 pt-2">
            <.button
              type="button"
              variant="ghost"
              phx-click="cancel_edit_periodical_task"
              class="flex-1"
            >
              Cancel
            </.button>
            <.button type="submit" class="flex-1">
              Save Schedule
            </.button>
          </div>
        </.form>
      </div>

      <div
        :if={@periodical_tasks == [] && !@editing_periodical_task}
        class="text-center py-8 text-gray-500 border border-dashed border-gray-700 rounded-lg"
      >
        <.icon name="hero-clock" class="w-8 h-8 mx-auto mb-2 opacity-50" />
        <p class="text-sm">No scheduled tasks yet</p>
        <p class="text-xs mt-1">Click "New Schedule" to create one</p>
      </div>

      <div :if={@periodical_tasks != [] && !@editing_periodical_task} class="space-y-2">
        <div
          :for={task <- @periodical_tasks}
          class={[
            "p-4 bg-gray-800/50 border rounded-lg",
            task.enabled && "border-gray-700 hover:border-gray-600",
            !task.enabled && "border-gray-700/50 opacity-60"
          ]}
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <.icon name="hero-calendar" class="w-4 h-4 text-brand-400" />
                <span class="font-medium text-white">{task.title}</span>
                <span class={[
                  "px-1.5 py-0.5 text-xs rounded",
                  task.enabled && "bg-green-600/20 text-green-400",
                  !task.enabled && "bg-gray-700 text-gray-400"
                ]}>
                  {if task.enabled, do: "Active", else: "Paused"}
                </span>
                <span class="px-1.5 py-0.5 text-xs bg-gray-700 text-gray-400 rounded">
                  #{task.execution_count} runs
                </span>
              </div>
              <p :if={task.description} class="text-xs text-gray-400 mt-1 truncate">
                {String.slice(task.description || "", 0, 80)}<span :if={
                  String.length(task.description || "") > 80
                }>...</span>
              </p>
              <div class="flex flex-wrap gap-x-3 gap-y-1 mt-2 text-xs text-gray-500">
                <div class="flex items-center gap-1">
                  <.icon name="hero-clock" class="w-3 h-3" />
                  <span class="font-mono">{task.schedule}</span>
                </div>
                <div>
                  <span class="text-gray-600">Executor:</span>
                  {executor_label(task.executor)}
                </div>
                <div :if={task.last_executed_at}>
                  <span class="text-gray-600">Last:</span>
                  {format_datetime(task.last_executed_at)}
                </div>
              </div>
              <div :if={task.enabled && task.next_execution_at} class="mt-2 flex items-center gap-2">
                <span class="text-xs text-gray-500">Next run:</span>
                <span class="text-sm font-medium text-brand-400">
                  {format_datetime(task.next_execution_at)}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-1 ml-2">
              <button
                phx-click="toggle_periodical_task"
                phx-value-id={task.id}
                class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                title={if task.enabled, do: "Pause", else: "Resume"}
              >
                <.icon :if={task.enabled} name="hero-pause" class="w-4 h-4" />
                <.icon :if={!task.enabled} name="hero-play" class="w-4 h-4" />
              </button>
              <button
                phx-click="edit_periodical_task"
                phx-value-id={task.id}
                class="p-1.5 text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
              >
                <.icon name="hero-pencil" class="w-4 h-4" />
              </button>
              <button
                phx-click="delete_periodical_task"
                phx-value-id={task.id}
                data-confirm="Delete this scheduled task?"
                class="p-1.5 text-gray-400 hover:text-red-400 hover:bg-gray-700 rounded transition-colors"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp executor_label(executor) do
    case executor do
      :claude_code -> "Claude Code"
      :gemini_cli -> "Gemini CLI"
      :codex -> "Codex"
      :opencode -> "OpenCode"
      :cursor_agent -> "Cursor Agent"
      _ -> to_string(executor)
    end
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end

  # ============================================================================
  # System Tab
  # ============================================================================

  attr :system_tools, :list, default: []

  defp system_tab(assigns) do
    core_tools = Enum.filter(assigns.system_tools, &(&1.category == :core))
    optional_tools = Enum.filter(assigns.system_tools, &(&1.category == :optional))

    assigns =
      assigns
      |> assign(:core_tools, core_tools)
      |> assign(:optional_tools, optional_tools)

    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-medium text-gray-400 mb-1">System Tools Status</h3>
        <p class="text-xs text-gray-500">
          These CLI tools provide additional functionality. Install missing tools to unlock features.
        </p>
      </div>

      <div
        :if={@system_tools == []}
        class="text-center py-8 text-gray-500 border border-dashed border-gray-700 rounded-lg"
      >
        <.icon name="hero-cog-6-tooth" class="w-8 h-8 mx-auto mb-2 opacity-50" />
        <p class="text-sm">Unable to load system tools</p>
      </div>

      <div :if={@system_tools != []} class="space-y-6">
        <div :if={@core_tools != []} class="space-y-2">
          <h4 class="text-sm font-medium text-gray-400 flex items-center gap-2">
            Core Tools (Required)
            <span class="text-xs text-gray-500">
              ({length(Enum.filter(@core_tools, & &1.available))}/{length(@core_tools)} available)
            </span>
          </h4>
          <div class="space-y-2">
            <.tool_item :for={tool <- @core_tools} tool={tool} />
          </div>
        </div>

        <div :if={@optional_tools != []} class="space-y-2">
          <h4 class="text-sm font-medium text-gray-400 flex items-center gap-2">
            Optional Tools
            <span class="text-xs text-gray-500">
              ({length(Enum.filter(@optional_tools, & &1.available))}/{length(@optional_tools)} available)
            </span>
          </h4>
          <div class="space-y-2">
            <.tool_item :for={tool <- @optional_tools} tool={tool} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :tool, :map, required: true

  defp tool_item(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-between p-3 rounded-lg border",
      @tool.available && "bg-gray-800/50 border-gray-700",
      !@tool.available && "bg-gray-800/30 border-gray-700/50 opacity-60"
    ]}>
      <div class="flex items-center gap-3">
        <div class={[
          "w-2 h-2 rounded-full",
          @tool.available && "bg-green-500",
          !@tool.available && "bg-gray-500"
        ]} />
        <div>
          <div class="flex items-center gap-2">
            <span class="font-medium text-white">{@tool.display_name}</span>
            <span :if={@tool.version} class="text-xs text-gray-500">v{@tool.version}</span>
          </div>
          <p :if={@tool.description} class="text-xs text-gray-400 mt-0.5">{@tool.description}</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <span :if={@tool.feature} class="text-xs px-2 py-0.5 rounded-full bg-gray-700 text-gray-300">
          {@tool.feature}
        </span>
        <span class={[
          "text-xs px-2 py-0.5 rounded",
          @tool.available && "bg-green-900/50 text-green-400",
          !@tool.available && "bg-gray-700/50 text-gray-500"
        ]}>
          {if @tool.available, do: "Available", else: "Not Found"}
        </span>
      </div>
    </div>
    """
  end
end
