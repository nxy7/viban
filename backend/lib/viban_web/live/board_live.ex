defmodule VibanWeb.Live.BoardLive do
  @moduledoc """
  Board LiveView for KanbanLite - displays the Kanban board with columns and tasks.
  Full-featured version with activity feed, executor chat, and all SolidJS features.
  """

  use VibanWeb, :live_view

  alias Viban.KanbanLite.{Board, Column, Task, TaskTemplate, Hook, ColumnHook, PeriodicalTask}
  alias Viban.Kanban.SystemHooks.Registry, as: SystemHooks
  alias Viban.AppRuntime.SystemTools
  alias VibanWeb.Live.BoardLive.TaskPanelComponent

  import VibanWeb.Live.BoardLive.Components.BoardHeader
  import VibanWeb.Live.BoardLive.Components.BoardSettings
  import VibanWeb.Live.BoardLive.Components.Column
  import VibanWeb.Live.BoardLive.Components.ColumnSettings
  import VibanWeb.Live.BoardLive.Components.Modals

  alias Viban.KanbanLite.Repository

  require Logger

  # ============================================================================
  # Mount and Params
  # ============================================================================

  @impl true
  def mount(%{"board_id" => board_id} = params, session, socket) do
    user_id = session["user_id"] || Ash.UUID.generate()

    case Board.get(board_id) do
      {:ok, board} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Viban.PubSub, "board:#{board_id}")
        end

        columns = Column.for_board!(board_id)
        tasks = load_all_tasks(columns)

        socket =
          socket
          |> assign(:user_id, user_id)
          |> assign(:board, board)
          |> assign(:columns, columns)
          |> assign(:tasks, tasks)
          |> assign(:filter_text, "")
          |> assign(:show_create_modal, false)
          |> assign(:create_column_id, nil)
          |> assign(:selected_task, nil)
          |> assign(:show_shortcuts_help, false)
          |> assign(:show_delete_confirm, false)
          |> assign(:delete_task_id, nil)
          |> assign(:form, to_form(%{"title" => "", "description" => ""}))
          |> assign(:show_pr_modal, false)
          |> assign(:pr_form, to_form(%{"title" => "", "body" => "", "base_branch" => "main"}))
          |> assign(:show_settings, false)
          |> assign(:settings_tab, :general)
          |> assign(:editing_repo, false)
          |> assign(:repo_form, nil)
          |> assign(:show_column_settings, false)
          |> assign(:column_settings_column, nil)
          |> assign(:column_settings_tab, :general)
          |> assign(:column_settings_form, nil)
          |> assign(:show_delete_column_tasks, false)
          |> assign(:column_hooks, [])
          |> assign(:available_hooks, [])
          |> assign(:templates, [])
          |> assign(:editing_template, nil)
          |> assign(:template_form, nil)
          |> assign(:hooks, [])
          |> assign(:system_hooks, SystemHooks.all())
          |> assign(:editing_hook, nil)
          |> assign(:hook_form, nil)
          |> assign(:hook_kind, :script)
          |> assign(:periodical_tasks, [])
          |> assign(:editing_periodical_task, nil)
          |> assign(:periodical_task_form, nil)
          |> assign(:system_tools, [])
          |> load_repository(board_id)
          |> maybe_load_task(params)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Board not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = maybe_load_task(socket, params)
    {:noreply, socket}
  end

  defp load_repository(socket, board_id) do
    case Repository.for_board(board_id) do
      {:ok, [repo | _]} -> assign(socket, :repository, repo)
      _ -> assign(socket, :repository, nil)
    end
  end

  defp maybe_load_task(socket, %{"task_id" => task_id}) do
    case Task.get(task_id) do
      {:ok, task} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Viban.PubSub, "task:#{task_id}")
        end

        assign(socket, :selected_task, task)

      {:error, _} ->
        socket
    end
  end

  defp maybe_load_task(socket, _), do: socket

  defp load_all_tasks(columns) do
    columns
    |> Enum.flat_map(fn col -> Task.for_column!(col.id) end)
    |> Map.new(&{&1.id, &1})
  end

  # ============================================================================
  # Render
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div id="board-sound-system" phx-hook="SoundSystem"></div>
    <div id="board-shortcuts" phx-hook="KeyboardShortcuts" class="h-screen flex flex-col bg-gray-950 text-white overflow-hidden">
      <.board_header board={@board} filter_text={@filter_text} columns={@columns} />

      <main class="flex-1 p-6 overflow-hidden">
        <div class="flex gap-4 h-full overflow-x-auto pb-4" id="board-columns">
          <.column
            :for={column <- @columns}
            column={column}
            board_id={@board.id}
            tasks={tasks_for_column(@tasks, column.id, @filter_text)}
            on_add_click={JS.push("show_create_modal", value: %{column_id: column.id})}
          />

          <div
            :if={@columns == []}
            class="flex items-center justify-center min-w-[280px] h-[200px] bg-gray-900/50 border border-gray-800 border-dashed rounded-xl text-gray-500"
          >
            No columns yet
          </div>
        </div>
      </main>

      <.create_task_modal
        :if={@show_create_modal}
        form={@form}
        column_id={@create_column_id}
        column_name={get_column_name(@columns, @create_column_id)}
      />

      <.live_component
        :if={@selected_task}
        module={TaskPanelComponent}
        id={"task-panel-#{@selected_task.id}"}
        task={@selected_task}
        columns={@columns}
        board={@board}
        on_close={JS.patch(~p"/board/#{@board.id}")}
      />

      <.create_pr_modal
        :if={@show_pr_modal && @selected_task}
        task={@selected_task}
        form={@pr_form}
      />

      <.shortcuts_help_modal :if={@show_shortcuts_help} task_open={@selected_task != nil} />

      <.delete_confirm_modal :if={@show_delete_confirm} />

      <.board_settings_panel
        show={@show_settings}
        board={@board}
        active_tab={@settings_tab}
        columns={@columns}
        repository={@repository}
        repo_form={@repo_form}
        editing_repo={@editing_repo}
        templates={@templates}
        editing_template={@editing_template}
        template_form={@template_form}
        hooks={@hooks}
        system_hooks={@system_hooks}
        editing_hook={@editing_hook}
        hook_form={@hook_form}
        hook_kind={@hook_kind}
        periodical_tasks={@periodical_tasks}
        editing_periodical_task={@editing_periodical_task}
        periodical_task_form={@periodical_task_form}
        system_tools={@system_tools}
      />

      <.column_settings_modal
        :if={@column_settings_column}
        show={@show_column_settings}
        column={@column_settings_column}
        active_tab={@column_settings_tab}
        form={@column_settings_form}
        show_delete_confirm={@show_delete_column_tasks}
        column_hooks={@column_hooks}
        available_hooks={@available_hooks}
        all_hooks={@hooks}
        all_system_hooks={@system_hooks}
      />
    </div>
    """
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp tasks_for_column(tasks, column_id, filter_text) do
    tasks
    |> Map.values()
    |> Enum.filter(&(&1.column_id == column_id))
    |> filter_tasks(filter_text)
    |> Enum.sort_by(& &1.position)
  end

  defp filter_tasks(tasks, ""), do: tasks

  defp filter_tasks(tasks, filter_text) do
    filter_lower = String.downcase(filter_text)

    Enum.filter(tasks, fn task ->
      String.contains?(String.downcase(task.title), filter_lower) ||
        (task.description && String.contains?(String.downcase(task.description), filter_lower))
    end)
  end

  defp get_column_name(columns, column_id) do
    case Enum.find(columns, &(&1.id == column_id)) do
      nil -> "Unknown"
      column -> column.name
    end
  end

  defp navigate_task(socket, direction) do
    all_tasks =
      socket.assigns.columns
      |> Enum.flat_map(fn col ->
        tasks_for_column(socket.assigns.tasks, col.id, socket.assigns.filter_text)
      end)

    case all_tasks do
      [] ->
        socket

      tasks ->
        current_id = socket.assigns.selected_task && socket.assigns.selected_task.id
        current_index = Enum.find_index(tasks, &(&1.id == current_id)) || -1

        new_index =
          case direction do
            :next -> min(current_index + 1, length(tasks) - 1)
            :prev -> max(current_index - 1, 0)
          end

        new_task = Enum.at(tasks, new_index)

        socket
        |> assign(:selected_task, new_task)
        |> push_patch(to: ~p"/board/#{socket.assigns.board.id}/task/#{new_task.id}")
    end
  end

  defp broadcast_update(board_id, message) do
    Phoenix.PubSub.broadcast(Viban.PubSub, "board:#{board_id}", message)
  end

  # ============================================================================
  # Board Event Handlers
  # ============================================================================

  @impl true
  def handle_event("filter", %{"value" => value}, socket) do
    {:noreply, assign(socket, :filter_text, value)}
  end

  def handle_event("shortcut_help", _, socket) do
    {:noreply, assign(socket, :show_shortcuts_help, true)}
  end

  def handle_event("hide_shortcuts_help", _, socket) do
    {:noreply, assign(socket, :show_shortcuts_help, false)}
  end

  def handle_event("show_settings", _, socket) do
    board_id = socket.assigns.board.id
    templates = load_templates(board_id)
    hooks = load_hooks(board_id)
    periodical_tasks = load_periodical_tasks(board_id)
    system_tools = load_system_tools()

    {:noreply,
     socket
     |> assign(:show_settings, true)
     |> assign(:templates, templates)
     |> assign(:hooks, hooks)
     |> assign(:periodical_tasks, periodical_tasks)
     |> assign(:system_tools, system_tools)}
  end

  defp load_templates(board_id) do
    case TaskTemplate.for_board(board_id) do
      {:ok, templates} -> templates
      _ -> []
    end
  end

  defp load_hooks(board_id) do
    case Hook.for_board(board_id) do
      {:ok, hooks} -> hooks
      _ -> []
    end
  end

  defp load_periodical_tasks(board_id) do
    case PeriodicalTask.for_board(board_id) do
      {:ok, tasks} -> tasks
      _ -> []
    end
  end

  defp load_system_tools do
    case SystemTools.list_tools() do
      {:ok, tools} -> tools
      _ -> []
    end
  end

  def handle_event("hide_settings", _, socket) do
    {:noreply,
     socket
     |> assign(:show_settings, false)
     |> assign(:editing_repo, false)
     |> assign(:repo_form, nil)}
  end

  def handle_event("settings_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)
    {:noreply, assign(socket, :settings_tab, tab_atom)}
  end

  def handle_event("edit_repo", _, socket) do
    repo = socket.assigns.repository

    form_data =
      if repo do
        %{
          "name" => repo.name || "",
          "local_path" => repo.local_path || "",
          "default_branch" => repo.default_branch || "main"
        }
      else
        %{"name" => "", "local_path" => "", "default_branch" => "main"}
      end

    {:noreply,
     socket
     |> assign(:editing_repo, true)
     |> assign(:repo_form, to_form(form_data))}
  end

  def handle_event("cancel_edit_repo", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_repo, false)
     |> assign(:repo_form, nil)}
  end

  def handle_event("save_repository", params, socket) do
    board_id = socket.assigns.board.id
    repo = socket.assigns.repository

    result =
      if repo do
        Repository.update(repo, %{
          name: params["name"],
          local_path: params["local_path"],
          default_branch: params["default_branch"]
        })
      else
        Repository.create(%{
          name: params["name"],
          local_path: params["local_path"],
          default_branch: params["default_branch"],
          board_id: board_id
        })
      end

    case result do
      {:ok, updated_repo} ->
        {:noreply,
         socket
         |> assign(:repository, updated_repo)
         |> assign(:editing_repo, false)
         |> assign(:repo_form, nil)
         |> put_flash(:info, "Repository saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save repository")}
    end
  end

  # ============================================================================
  # Template Event Handlers
  # ============================================================================

  def handle_event("new_template", _, socket) do
    form_data = %{"name" => "", "description_template" => ""}
    {:noreply, socket |> assign(:editing_template, :new) |> assign(:template_form, to_form(form_data))}
  end

  def handle_event("edit_template", %{"id" => template_id}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.id == template_id))

    if template do
      form_data = %{
        "id" => template.id,
        "name" => template.name,
        "description_template" => template.description_template || ""
      }

      {:noreply, socket |> assign(:editing_template, template) |> assign(:template_form, to_form(form_data))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_template", _, socket) do
    {:noreply, socket |> assign(:editing_template, nil) |> assign(:template_form, nil)}
  end

  def handle_event("save_template", params, socket) do
    board_id = socket.assigns.board.id

    result =
      case socket.assigns.editing_template do
        :new ->
          position = length(socket.assigns.templates)

          TaskTemplate.create(%{
            name: params["name"],
            description_template: params["description_template"],
            position: position,
            board_id: board_id
          })

        template ->
          TaskTemplate.update(template, %{
            name: params["name"],
            description_template: params["description_template"]
          })
      end

    case result do
      {:ok, _} ->
        templates = load_templates(board_id)

        {:noreply,
         socket
         |> assign(:templates, templates)
         |> assign(:editing_template, nil)
         |> assign(:template_form, nil)
         |> put_flash(:info, "Template saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save template")}
    end
  end

  def handle_event("delete_template", %{"id" => template_id}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.id == template_id))

    if template do
      case TaskTemplate.destroy(template) do
        :ok ->
          templates = load_templates(socket.assigns.board.id)

          {:noreply,
           socket
           |> assign(:templates, templates)
           |> assign(:editing_template, nil)
           |> assign(:template_form, nil)
           |> put_flash(:info, "Template deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete template")}
      end
    else
      {:noreply, socket}
    end
  end

  # ============================================================================
  # Hook Event Handlers
  # ============================================================================

  def handle_event("new_hook", _, socket) do
    form_data = %{
      "name" => "",
      "command" => "",
      "agent_prompt" => "",
      "agent_executor" => "claude_code",
      "agent_auto_approve" => false,
      "default_execute_once" => false,
      "default_transparent" => false
    }

    {:noreply,
     socket
     |> assign(:editing_hook, :new)
     |> assign(:hook_kind, :script)
     |> assign(:hook_form, to_form(form_data))}
  end

  def handle_event("edit_hook", %{"id" => hook_id}, socket) do
    hook = Enum.find(socket.assigns.hooks, &(&1.id == hook_id))

    if hook do
      form_data = %{
        "id" => hook.id,
        "name" => hook.name,
        "command" => hook.command || "",
        "agent_prompt" => hook.agent_prompt || "",
        "agent_executor" => Atom.to_string(hook.agent_executor || :claude_code),
        "agent_auto_approve" => hook.agent_auto_approve || false,
        "default_execute_once" => hook.default_execute_once || false,
        "default_transparent" => hook.default_transparent || false
      }

      {:noreply,
       socket
       |> assign(:editing_hook, hook)
       |> assign(:hook_kind, hook.hook_kind)
       |> assign(:hook_form, to_form(form_data))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_hook", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_hook, nil)
     |> assign(:hook_form, nil)}
  end

  def handle_event("set_hook_kind", %{"kind" => kind}, socket) do
    kind_atom = String.to_existing_atom(kind)
    {:noreply, assign(socket, :hook_kind, kind_atom)}
  end

  def handle_event("save_hook", params, socket) do
    board_id = socket.assigns.board.id
    hook_kind = socket.assigns.hook_kind

    result =
      case socket.assigns.editing_hook do
        :new ->
          if hook_kind == :script do
            Hook.create_script_hook(%{
              name: params["name"],
              command: params["command"],
              board_id: board_id,
              default_execute_once: params["default_execute_once"] == "true",
              default_transparent: params["default_transparent"] == "true"
            })
          else
            Hook.create_agent_hook(%{
              name: params["name"],
              agent_prompt: params["agent_prompt"],
              agent_executor: String.to_existing_atom(params["agent_executor"] || "claude_code"),
              agent_auto_approve: params["agent_auto_approve"] == "true",
              board_id: board_id,
              default_execute_once: params["default_execute_once"] == "true",
              default_transparent: params["default_transparent"] == "true"
            })
          end

        hook ->
          Hook.update(hook, %{
            name: params["name"],
            command: if(hook.hook_kind == :script, do: params["command"], else: nil),
            agent_prompt: if(hook.hook_kind == :agent, do: params["agent_prompt"], else: nil),
            agent_executor:
              if(hook.hook_kind == :agent,
                do: String.to_existing_atom(params["agent_executor"] || "claude_code"),
                else: nil
              ),
            agent_auto_approve:
              if(hook.hook_kind == :agent, do: params["agent_auto_approve"] == "true", else: nil),
            default_execute_once: params["default_execute_once"] == "true",
            default_transparent: params["default_transparent"] == "true"
          })
      end

    case result do
      {:ok, _} ->
        hooks = load_hooks(board_id)

        {:noreply,
         socket
         |> assign(:hooks, hooks)
         |> assign(:editing_hook, nil)
         |> assign(:hook_form, nil)
         |> put_flash(:info, "Hook saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save hook")}
    end
  end

  def handle_event("delete_hook", %{"id" => hook_id}, socket) do
    hook = Enum.find(socket.assigns.hooks, &(&1.id == hook_id))

    if hook do
      case Hook.destroy(hook) do
        :ok ->
          hooks = load_hooks(socket.assigns.board.id)

          {:noreply,
           socket
           |> assign(:hooks, hooks)
           |> assign(:editing_hook, nil)
           |> assign(:hook_form, nil)
           |> put_flash(:info, "Hook deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete hook")}
      end
    else
      {:noreply, socket}
    end
  end

  # ============================================================================
  # Periodical Task Event Handlers
  # ============================================================================

  def handle_event("new_periodical_task", _, socket) do
    form_data = %{
      "title" => "",
      "description" => "",
      "schedule" => "0 9 * * 1",
      "executor" => "claude_code",
      "enabled" => true
    }

    {:noreply,
     socket
     |> assign(:editing_periodical_task, :new)
     |> assign(:periodical_task_form, to_form(form_data))}
  end

  def handle_event("edit_periodical_task", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.periodical_tasks, &(&1.id == id))

    if task do
      form_data = %{
        "id" => task.id,
        "title" => task.title,
        "description" => task.description || "",
        "schedule" => task.schedule,
        "executor" => Atom.to_string(task.executor || :claude_code),
        "enabled" => task.enabled
      }

      {:noreply,
       socket
       |> assign(:editing_periodical_task, task)
       |> assign(:periodical_task_form, to_form(form_data))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_edit_periodical_task", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_periodical_task, nil)
     |> assign(:periodical_task_form, nil)}
  end

  def handle_event("save_periodical_task", params, socket) do
    board_id = socket.assigns.board.id

    result =
      case socket.assigns.editing_periodical_task do
        :new ->
          PeriodicalTask.create(%{
            title: params["title"],
            description: params["description"],
            schedule: params["schedule"],
            executor: String.to_existing_atom(params["executor"] || "claude_code"),
            enabled: true,
            board_id: board_id
          })

        task ->
          PeriodicalTask.update(task, %{
            title: params["title"],
            description: params["description"],
            schedule: params["schedule"],
            executor: String.to_existing_atom(params["executor"] || "claude_code"),
            enabled: params["enabled"] == "true"
          })
      end

    case result do
      {:ok, _} ->
        periodical_tasks = load_periodical_tasks(board_id)

        {:noreply,
         socket
         |> assign(:periodical_tasks, periodical_tasks)
         |> assign(:editing_periodical_task, nil)
         |> assign(:periodical_task_form, nil)
         |> put_flash(:info, "Scheduled task saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save scheduled task")}
    end
  end

  def handle_event("toggle_periodical_task", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.periodical_tasks, &(&1.id == id))

    if task do
      case PeriodicalTask.update(task, %{enabled: !task.enabled}) do
        {:ok, _} ->
          periodical_tasks = load_periodical_tasks(socket.assigns.board.id)
          {:noreply, assign(socket, :periodical_tasks, periodical_tasks)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to toggle task")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_periodical_task", %{"id" => id}, socket) do
    task = Enum.find(socket.assigns.periodical_tasks, &(&1.id == id))

    if task do
      case PeriodicalTask.destroy(task) do
        :ok ->
          periodical_tasks = load_periodical_tasks(socket.assigns.board.id)

          {:noreply,
           socket
           |> assign(:periodical_tasks, periodical_tasks)
           |> assign(:editing_periodical_task, nil)
           |> assign(:periodical_task_form, nil)
           |> put_flash(:info, "Scheduled task deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete task")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_cron_preset", %{"cron" => cron}, socket) do
    if socket.assigns.periodical_task_form do
      form_data = %{
        "title" => socket.assigns.periodical_task_form[:title].value,
        "description" => socket.assigns.periodical_task_form[:description].value,
        "schedule" => cron,
        "executor" => socket.assigns.periodical_task_form[:executor].value
      }

      {:noreply, assign(socket, :periodical_task_form, to_form(form_data))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_column_settings", %{"column_id" => column_id}, socket) do
    column = Enum.find(socket.assigns.columns, &(&1.id == column_id))

    if column do
      description = get_in(column.settings || %{}, ["description"]) || ""
      max_concurrent = get_in(column.settings || %{}, ["max_concurrent_tasks"]) || 3

      form_data = %{
        "name" => column.name,
        "color" => column.color || "#6366f1",
        "description" => description,
        "max_concurrent_tasks" => max_concurrent
      }

      column_hooks = load_column_hooks(column_id)
      custom_hooks = load_hooks(socket.assigns.board.id)
      system_hooks = SystemHooks.all()
      available_hooks = build_available_hooks(custom_hooks, system_hooks, column_hooks)

      {:noreply,
       socket
       |> assign(:show_column_settings, true)
       |> assign(:column_settings_column, column)
       |> assign(:column_settings_tab, :general)
       |> assign(:column_settings_form, to_form(form_data))
       |> assign(:show_delete_column_tasks, false)
       |> assign(:column_hooks, column_hooks)
       |> assign(:available_hooks, available_hooks)
       |> assign(:hooks, custom_hooks)}
    else
      {:noreply, socket}
    end
  end

  defp load_column_hooks(column_id) do
    case ColumnHook.for_column(column_id) do
      {:ok, hooks} -> hooks
      _ -> []
    end
  end

  defp build_available_hooks(custom_hooks, system_hooks, assigned_hooks) do
    assigned_ids = Enum.map(assigned_hooks, & &1.hook_id)

    custom =
      custom_hooks
      |> Enum.reject(&(&1.id in assigned_ids))
      |> Enum.map(&%{id: &1.id, name: &1.name, is_system: false, hook_kind: &1.hook_kind})

    system =
      system_hooks
      |> Enum.reject(&(&1.id in assigned_ids))
      |> Enum.map(&%{id: &1.id, name: &1.name, is_system: true, hook_kind: :system})

    system ++ custom
  end

  def handle_event("hide_column_settings", _, socket) do
    {:noreply,
     socket
     |> assign(:show_column_settings, false)
     |> assign(:column_settings_column, nil)
     |> assign(:column_settings_form, nil)
     |> assign(:show_delete_column_tasks, false)}
  end

  def handle_event("column_settings_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_existing_atom(tab)
    {:noreply, assign(socket, :column_settings_tab, tab_atom)}
  end

  def handle_event("select_column_color", %{"color" => color}, socket) do
    form = socket.assigns.column_settings_form
    form_data = Map.put(form.source, "color", color)
    {:noreply, assign(socket, :column_settings_form, to_form(form_data))}
  end

  def handle_event("save_column_settings", params, socket) do
    column = socket.assigns.column_settings_column

    update_params = %{color: params["color"]}

    update_params =
      if column.name in ["TODO", "In Progress", "To Review", "Done", "Cancelled"] do
        update_params
      else
        Map.put(update_params, :name, params["name"])
      end

    with {:ok, updated_column} <- Column.update(column, update_params),
         {:ok, updated_column} <- Column.update_settings(updated_column, %{"description" => params["description"]}) do
      columns =
        Enum.map(socket.assigns.columns, fn c ->
          if c.id == updated_column.id, do: updated_column, else: c
        end)

      {:noreply,
       socket
       |> assign(:columns, columns)
       |> assign(:column_settings_column, updated_column)
       |> assign(:show_column_settings, false)
       |> put_flash(:info, "Column settings saved")}
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save column settings")}
    end
  end

  def handle_event("show_delete_column_tasks", _, socket) do
    {:noreply, assign(socket, :show_delete_column_tasks, true)}
  end

  def handle_event("cancel_delete_column_tasks", _, socket) do
    {:noreply, assign(socket, :show_delete_column_tasks, false)}
  end

  def handle_event("confirm_delete_column_tasks", _, socket) do
    column = socket.assigns.column_settings_column

    case Column.delete_all_tasks(column.id) do
      {:ok, count} ->
        tasks =
          socket.assigns.tasks
          |> Enum.reject(fn {_id, task} -> task.column_id == column.id end)
          |> Map.new()

        {:noreply,
         socket
         |> assign(:tasks, tasks)
         |> assign(:show_column_settings, false)
         |> assign(:show_delete_column_tasks, false)
         |> put_flash(:info, "Deleted #{count} tasks")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete tasks")}
    end
  end

  def handle_event("toggle_concurrency_limit", _, socket) do
    column = socket.assigns.column_settings_column
    current_limit = get_in(column.settings || %{}, ["max_concurrent_tasks"])

    new_settings =
      if current_limit do
        %{"max_concurrent_tasks" => nil}
      else
        %{"max_concurrent_tasks" => 3}
      end

    case Column.update_settings(column, new_settings) do
      {:ok, updated_column} ->
        columns =
          Enum.map(socket.assigns.columns, fn c ->
            if c.id == updated_column.id, do: updated_column, else: c
          end)

        form_data = %{
          "name" => updated_column.name,
          "color" => updated_column.color || "#6366f1",
          "description" => get_in(updated_column.settings || %{}, ["description"]) || "",
          "max_concurrent_tasks" => get_in(updated_column.settings || %{}, ["max_concurrent_tasks"]) || 3
        }

        {:noreply,
         socket
         |> assign(:columns, columns)
         |> assign(:column_settings_column, updated_column)
         |> assign(:column_settings_form, to_form(form_data))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update settings")}
    end
  end

  def handle_event("save_concurrency_limit", _, socket) do
    column = socket.assigns.column_settings_column
    form = socket.assigns.column_settings_form
    limit = String.to_integer(form.source["max_concurrent_tasks"] || "3")

    new_settings = %{"max_concurrent_tasks" => limit}

    case Column.update_settings(column, new_settings) do
      {:ok, updated_column} ->
        columns =
          Enum.map(socket.assigns.columns, fn c ->
            if c.id == updated_column.id, do: updated_column, else: c
          end)

        {:noreply,
         socket
         |> assign(:columns, columns)
         |> assign(:column_settings_column, updated_column)
         |> put_flash(:info, "Concurrency limit saved")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save limit")}
    end
  end

  # ============================================================================
  # Column Hook Event Handlers
  # ============================================================================

  def handle_event("add_column_hook", %{"hook_id" => hook_id}, socket) do
    column = socket.assigns.column_settings_column
    position = length(socket.assigns.column_hooks)

    case ColumnHook.create(%{
           column_id: column.id,
           hook_id: hook_id,
           position: position,
           execute_once: false,
           transparent: false
         }) do
      {:ok, _} ->
        column_hooks = load_column_hooks(column.id)
        custom_hooks = load_hooks(socket.assigns.board.id)
        system_hooks = SystemHooks.all()
        available_hooks = build_available_hooks(custom_hooks, system_hooks, column_hooks)

        {:noreply,
         socket
         |> assign(:column_hooks, column_hooks)
         |> assign(:available_hooks, available_hooks)
         |> put_flash(:info, "Hook added")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add hook")}
    end
  end

  def handle_event("remove_column_hook", %{"id" => column_hook_id}, socket) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.destroy(column_hook) do
          :ok ->
            column = socket.assigns.column_settings_column
            column_hooks = load_column_hooks(column.id)
            custom_hooks = load_hooks(socket.assigns.board.id)
            system_hooks = SystemHooks.all()
            available_hooks = build_available_hooks(custom_hooks, system_hooks, column_hooks)

            {:noreply,
             socket
             |> assign(:column_hooks, column_hooks)
             |> assign(:available_hooks, available_hooks)
             |> put_flash(:info, "Hook removed")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to remove hook")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Hook not found")}
    end
  end

  def handle_event("toggle_column_hook_execute_once", %{"id" => column_hook_id}, socket) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.update(column_hook, %{execute_once: !column_hook.execute_once}) do
          {:ok, _} ->
            column_hooks = load_column_hooks(socket.assigns.column_settings_column.id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update hook")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_column_hook_transparent", %{"id" => column_hook_id}, socket) do
    case ColumnHook.get(column_hook_id) do
      {:ok, column_hook} ->
        case ColumnHook.update(column_hook, %{transparent: !column_hook.transparent}) do
          {:ok, _} ->
            column_hooks = load_column_hooks(socket.assigns.column_settings_column.id)
            {:noreply, assign(socket, :column_hooks, column_hooks)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update hook")}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  # ============================================================================
  # Keyboard Shortcut Handlers
  # ============================================================================

  def handle_event("shortcut_escape", _, socket) do
    cond do
      socket.assigns.show_column_settings ->
        {:noreply,
         socket
         |> assign(:show_column_settings, false)
         |> assign(:column_settings_column, nil)
         |> assign(:column_settings_form, nil)
         |> assign(:show_delete_column_tasks, false)}

      socket.assigns.show_settings ->
        {:noreply,
         socket
         |> assign(:show_settings, false)
         |> assign(:editing_repo, false)
         |> assign(:repo_form, nil)}

      socket.assigns.show_delete_confirm ->
        {:noreply,
         socket
         |> assign(:show_delete_confirm, false)
         |> assign(:delete_task_id, nil)}

      socket.assigns.show_shortcuts_help ->
        {:noreply, assign(socket, :show_shortcuts_help, false)}

      socket.assigns.show_create_modal ->
        {:noreply, assign(socket, :show_create_modal, false)}

      socket.assigns.selected_task ->
        {:noreply,
         socket
         |> assign(:selected_task, nil)
         |> push_patch(to: ~p"/board/#{socket.assigns.board.id}")}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("shortcut_new_task", _, socket) do
    todo_column = Enum.find(socket.assigns.columns, fn c -> String.upcase(c.name) == "TODO" end)

    if todo_column do
      {:noreply,
       socket
       |> assign(:show_create_modal, true)
       |> assign(:create_column_id, todo_column.id)
       |> assign(:form, to_form(%{"title" => "", "description" => ""}))}
    else
      {:noreply, put_flash(socket, :error, "No TODO column found")}
    end
  end

  def handle_event("shortcut_focus_search", _, socket) do
    {:noreply, push_event(socket, "focus_search", %{})}
  end

  def handle_event("shortcut_prev_task", _, socket) do
    {:noreply, navigate_task(socket, :prev)}
  end

  def handle_event("shortcut_next_task", _, socket) do
    {:noreply, navigate_task(socket, :next)}
  end

  def handle_event("shortcut_delete_task", _, socket) do
    case socket.assigns.selected_task do
      nil ->
        {:noreply, socket}

      task ->
        {:noreply,
         socket
         |> assign(:show_delete_confirm, true)
         |> assign(:delete_task_id, task.id)}
    end
  end

  # ============================================================================
  # Create Task Modal Handlers
  # ============================================================================

  def handle_event("show_create_modal", %{"column_id" => column_id}, socket)
      when is_binary(column_id) and column_id != "" do
    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:create_column_id, column_id)
     |> assign(:form, to_form(%{"title" => "", "description" => ""}))}
  end

  def handle_event("show_create_modal", _params, socket) do
    todo_column = Enum.find(socket.assigns.columns, fn c -> String.upcase(c.name) == "TODO" end)

    if todo_column do
      {:noreply,
       socket
       |> assign(:show_create_modal, true)
       |> assign(:create_column_id, todo_column.id)
       |> assign(:form, to_form(%{"title" => "", "description" => ""}))}
    else
      {:noreply, put_flash(socket, :error, "No TODO column found")}
    end
  end

  def handle_event("hide_create_modal", _, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  def handle_event("create_task", %{"title" => title, "description" => description, "column_id" => column_id}, socket) do
    case Task.create(%{
           title: title,
           description: if(description == "", do: nil, else: description),
           column_id: column_id
         }) do
      {:ok, task} ->
        tasks = Map.put(socket.assigns.tasks, task.id, task)
        broadcast_update(socket.assigns.board.id, {:task_created, task})

        {:noreply,
         socket
         |> assign(:tasks, tasks)
         |> assign(:show_create_modal, false)
         |> put_flash(:info, "Task created!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create task")}
    end
  end

  # ============================================================================
  # Delete Task Handlers
  # ============================================================================

  def handle_event("confirm_delete_task", _, socket) do
    task_id = socket.assigns.delete_task_id

    with {:ok, task} <- Task.get(task_id),
         :ok <- Task.destroy(task) do
      tasks = Map.delete(socket.assigns.tasks, task_id)
      broadcast_update(socket.assigns.board.id, {:task_deleted, task_id})

      {:noreply,
       socket
       |> assign(:tasks, tasks)
       |> assign(:selected_task, nil)
       |> assign(:show_delete_confirm, false)
       |> assign(:delete_task_id, nil)
       |> push_patch(to: ~p"/board/#{socket.assigns.board.id}")
       |> put_flash(:info, "Task deleted")}
    else
      _ ->
        {:noreply,
         socket
         |> assign(:show_delete_confirm, false)
         |> put_flash(:error, "Failed to delete task")}
    end
  end

  def handle_event("cancel_delete_task", _, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_confirm, false)
     |> assign(:delete_task_id, nil)}
  end

  # ============================================================================
  # Task Move Handler (from drag & drop)
  # ============================================================================

  def handle_event("move_task", %{"task_id" => task_id, "column_id" => column_id} = params, socket) do
    with {:ok, task} <- Task.get(task_id) do
      move_params = %{column_id: column_id}

      move_params =
        case params do
          %{"before_task_id" => before_id} when before_id != "" ->
            Map.put(move_params, :before_task_id, before_id)

          %{"after_task_id" => after_id} when after_id != "" ->
            Map.put(move_params, :after_task_id, after_id)

          _ ->
            move_params
        end

      case Task.move(task, move_params) do
        {:ok, updated_task} ->
          tasks = Map.put(socket.assigns.tasks, task_id, updated_task)
          broadcast_update(socket.assigns.board.id, {:task_moved, updated_task})
          {:noreply, assign(socket, :tasks, tasks)}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  # ============================================================================
  # PR Modal Handlers
  # ============================================================================

  def handle_event("hide_pr_modal", _params, socket) do
    {:noreply, assign(socket, :show_pr_modal, false)}
  end

  def handle_event("create_pr", %{"title" => title, "body" => body, "base_branch" => base_branch, "task_id" => task_id}, socket) do
    case Task.create_pr(task_id, title, body, base_branch) do
      {:ok, result} ->
        case Task.get(task_id) do
          {:ok, updated_task} ->
            tasks = Map.put(socket.assigns.tasks, task_id, updated_task)
            broadcast_update(socket.assigns.board.id, {:task_updated, updated_task})

            {:noreply,
             socket
             |> assign(:tasks, tasks)
             |> assign(:selected_task, updated_task)
             |> assign(:show_pr_modal, false)
             |> put_flash(:info, "PR created: #{result.pr_url}")}

          _ ->
            {:noreply,
             socket
             |> assign(:show_pr_modal, false)
             |> put_flash(:info, "PR created: #{result.pr_url}")}
        end

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to create PR: #{inspect(error)}")}
    end
  end

  # ============================================================================
  # TaskPanelComponent Message Handlers
  # ============================================================================

  @impl true
  def handle_info({TaskPanelComponent, {:update_task, task_id, attrs}}, socket) do
    with {:ok, task} <- Task.get(task_id),
         {:ok, updated_task} <- Task.update(task, attrs) do
      tasks = Map.put(socket.assigns.tasks, task_id, updated_task)
      broadcast_update(socket.assigns.board.id, {:task_updated, updated_task})

      {:noreply,
       socket
       |> assign(:tasks, tasks)
       |> assign(:selected_task, updated_task)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_info({TaskPanelComponent, {:move_task, task_id, column_id}}, socket) do
    with {:ok, task} <- Task.get(task_id),
         {:ok, updated_task} <- Task.move(task, %{column_id: column_id}) do
      tasks = Map.put(socket.assigns.tasks, task_id, updated_task)
      broadcast_update(socket.assigns.board.id, {:task_moved, updated_task})

      {:noreply,
       socket
       |> assign(:tasks, tasks)
       |> assign(:selected_task, updated_task)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_info({TaskPanelComponent, {:create_worktree, task_id}}, socket) do
    case Task.create_worktree(task_id) do
      {:ok, result} ->
        case Task.get(task_id) do
          {:ok, updated_task} ->
            tasks = Map.put(socket.assigns.tasks, task_id, updated_task)
            broadcast_update(socket.assigns.board.id, {:task_updated, updated_task})

            {:noreply,
             socket
             |> assign(:tasks, tasks)
             |> assign(:selected_task, updated_task)
             |> put_flash(:info, "Branch created: #{result.branch}")}

          _ ->
            {:noreply, put_flash(socket, :info, "Branch created: #{result.branch}")}
        end

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to create branch: #{inspect(error)}")}
    end
  end

  def handle_info({TaskPanelComponent, {:show_pr_modal, task}}, socket) do
    pr_form =
      to_form(%{
        "title" => task.title,
        "body" => task.description || "",
        "base_branch" => "main"
      })

    {:noreply,
     socket
     |> assign(:show_pr_modal, true)
     |> assign(:pr_form, pr_form)}
  end

  def handle_info({TaskPanelComponent, {:duplicate_task, task_id}}, socket) do
    with {:ok, task} <- Task.get(task_id),
         {:ok, new_task} <-
           Task.create(%{
             title: "#{task.title} (copy)",
             description: task.description,
             column_id: task.column_id
           }) do
      tasks = Map.put(socket.assigns.tasks, new_task.id, new_task)
      broadcast_update(socket.assigns.board.id, {:task_created, new_task})

      {:noreply,
       socket
       |> assign(:tasks, tasks)
       |> put_flash(:info, "Task duplicated")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to duplicate task")}
    end
  end

  def handle_info({TaskPanelComponent, {:delete_task, task_id}}, socket) do
    with {:ok, task} <- Task.get(task_id),
         :ok <- Task.destroy(task) do
      tasks = Map.delete(socket.assigns.tasks, task_id)
      broadcast_update(socket.assigns.board.id, {:task_deleted, task_id})

      {:noreply,
       socket
       |> assign(:tasks, tasks)
       |> assign(:selected_task, nil)
       |> push_patch(to: ~p"/board/#{socket.assigns.board.id}")
       |> put_flash(:info, "Task deleted")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to delete task")}
    end
  end

  def handle_info({TaskPanelComponent, {:generate_subtasks, task_id}}, socket) do
    case Task.generate_subtasks(task_id) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Generating subtasks...")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to generate subtasks: #{inspect(error)}")}
    end
  end

  def handle_info({TaskPanelComponent, {:toggle_subtask, subtask_id, columns}}, socket) do
    with {:ok, subtask} <- Task.get(subtask_id) do
      done_column =
        Enum.find(columns, fn c ->
          String.downcase(c.name) in ["done", "completed"]
        end)

      todo_column =
        Enum.find(columns, fn c ->
          String.downcase(c.name) == "todo"
        end)

      target_column =
        if subtask.column_id == done_column.id do
          todo_column
        else
          done_column
        end

      if target_column do
        case Task.move(subtask, %{column_id: target_column.id}) do
          {:ok, updated_subtask} ->
            tasks = Map.put(socket.assigns.tasks, subtask_id, updated_subtask)
            broadcast_update(socket.assigns.board.id, {:task_moved, updated_subtask})
            {:noreply, assign(socket, :tasks, tasks)}

          _ ->
            {:noreply, socket}
        end
      else
        {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_info({TaskPanelComponent, {:clear_error, task_id}}, socket) do
    with {:ok, task} <- Task.get(task_id),
         {:ok, updated_task} <- Task.update(task, %{agent_status: :idle, error_message: nil}) do
      tasks = Map.put(socket.assigns.tasks, task_id, updated_task)
      broadcast_update(socket.assigns.board.id, {:task_updated, updated_task})

      {:noreply,
       socket
       |> assign(:tasks, tasks)
       |> assign(:selected_task, updated_task)}
    else
      _ -> {:noreply, socket}
    end
  end

  # ============================================================================
  # Board PubSub Handlers
  # ============================================================================

  def handle_info({:task_created, task}, socket) do
    tasks = Map.put(socket.assigns.tasks, task.id, task)
    {:noreply, assign(socket, :tasks, tasks)}
  end

  def handle_info({:task_updated, task}, socket) do
    tasks = Map.put(socket.assigns.tasks, task.id, task)

    socket =
      if socket.assigns.selected_task && socket.assigns.selected_task.id == task.id do
        assign(socket, :selected_task, task)
      else
        socket
      end

    {:noreply, assign(socket, :tasks, tasks)}
  end

  def handle_info({:task_moved, task}, socket) do
    tasks = Map.put(socket.assigns.tasks, task.id, task)

    socket =
      if socket.assigns.selected_task && socket.assigns.selected_task.id == task.id do
        assign(socket, :selected_task, task)
      else
        socket
      end

    {:noreply, assign(socket, :tasks, tasks)}
  end

  def handle_info({:task_deleted, task_id}, socket) do
    tasks = Map.delete(socket.assigns.tasks, task_id)

    socket =
      if socket.assigns.selected_task && socket.assigns.selected_task.id == task_id do
        socket
        |> assign(:selected_task, nil)
        |> push_patch(to: ~p"/board/#{socket.assigns.board.id}")
      else
        socket
      end

    {:noreply, assign(socket, :tasks, tasks)}
  end

  # ============================================================================
  # Task-specific PubSub Handlers (forwarded to TaskPanelComponent)
  # ============================================================================

  def handle_info({:new_message, message, executor_type}, socket) do
    if socket.assigns.selected_task do
      send_update(TaskPanelComponent,
        id: "task-panel-#{socket.assigns.selected_task.id}",
        task_message: {:new_message, message, executor_type}
      )
    end

    {:noreply, socket}
  end

  def handle_info({:executor_session_started, session}, socket) do
    if socket.assigns.selected_task do
      send_update(TaskPanelComponent,
        id: "task-panel-#{socket.assigns.selected_task.id}",
        task_message: {:executor_session_started, session}
      )
    end

    {:noreply, socket}
  end

  def handle_info({:executor_session_completed, session}, socket) do
    if socket.assigns.selected_task do
      send_update(TaskPanelComponent,
        id: "task-panel-#{socket.assigns.selected_task.id}",
        task_message: {:executor_session_completed, session}
      )
    end

    {:noreply, socket}
  end

  def handle_info(:executor_stopped, socket) do
    if socket.assigns.selected_task do
      send_update(TaskPanelComponent,
        id: "task-panel-#{socket.assigns.selected_task.id}",
        task_message: :executor_stopped
      )
    end

    {:noreply, socket}
  end

  def handle_info({:hook_execution_update, hook}, socket) do
    if socket.assigns.selected_task do
      send_update(TaskPanelComponent,
        id: "task-panel-#{socket.assigns.selected_task.id}",
        task_message: {:hook_execution_update, hook}
      )
    end

    {:noreply, socket}
  end

  def handle_info({:subtasks_generated, parent_task_id}, socket) do
    if socket.assigns.selected_task do
      send_update(TaskPanelComponent,
        id: "task-panel-#{socket.assigns.selected_task.id}",
        task_message: {:subtasks_generated, parent_task_id}
      )
    end

    {:noreply, socket}
  end

  # ============================================================================
  # Sound PubSub Handler
  # ============================================================================

  def handle_info({:play_sound, sound}, socket) do
    {:noreply, push_event(socket, "play_sound", %{sound: sound})}
  end

  def handle_info(_, socket), do: {:noreply, socket}
end
