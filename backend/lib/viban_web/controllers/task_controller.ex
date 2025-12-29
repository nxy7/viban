defmodule VibanWeb.TaskController do
  @moduledoc """
  API endpoints for task management.

  Provides endpoints for task refinement, subtask generation, and image retrieval.
  Most task CRUD operations are handled through Electric sync, but these endpoints
  provide additional AI-powered features.

  ## Endpoints

  - `POST /api/tasks/refine-preview` - Preview refined description before creating task
  - `POST /api/tasks/:task_id/refine` - Refine an existing task's description
  - `POST /api/tasks/:task_id/generate_subtasks` - Generate subtasks using AI
  - `GET /api/tasks/:task_id/subtasks` - Get subtasks for a parent task
  - `GET /api/tasks/:task_id/images/:image_id` - Serve a task image
  """

  use VibanWeb, :controller

  import VibanWeb.ControllerHelpers,
    only: [
      json_ok: 2,
      json_error: 3,
      extract_error_message: 1
    ]

  alias Viban.Kanban.Task
  alias Viban.Kanban.TaskImageManager
  alias Viban.LLM.TaskRefiner
  alias Viban.Workers.SubtaskGenerationWorker

  require Ash.Query
  require Logger

  @doc """
  Refines an existing task's description using LLM.

  Uses the task's title and current description to generate an improved,
  more detailed description suitable for AI agents.

  ## Path Parameters

  - `task_id` - The ID of the task to refine

  ## Response

  Returns the updated task with the refined description.
  """
  @spec refine(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def refine(conn, %{"task_id" => task_id}) do
    case Task.refine(task_id) do
      {:ok, result} ->
        json_ok(conn, %{
          task: %{
            id: result.id,
            title: result.title,
            description: result.description
          }
        })

      {:error, error} ->
        Logger.error("[TaskController] Refine failed: #{inspect(error)}")
        json_error(conn, :unprocessable_entity, extract_error_message(error))
    end
  end

  def refine(conn, _params) do
    json_error(conn, :bad_request, "task_id is required")
  end

  @doc """
  Refines a task description before creation (preview mode).

  Does not require an existing task - used in CreateTaskModal to preview
  what the refined description would look like before committing.

  ## Body Parameters

  - `title` (required) - The task title
  - `description` - Optional task description

  ## Response

  Returns the refined description text.
  """
  @spec refine_preview(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def refine_preview(conn, %{"title" => title} = params) do
    description = Map.get(params, "description")

    case TaskRefiner.refine(title, description) do
      {:ok, refined} ->
        json_ok(conn, %{refined_description: refined})

      {:error, error} ->
        Logger.error("[TaskController] Refine preview failed: #{inspect(error)}")
        json_error(conn, :unprocessable_entity, extract_error_message(error))
    end
  end

  def refine_preview(conn, _params) do
    json_error(conn, :bad_request, "title is required")
  end

  @doc """
  Generates subtasks for a parent task using AI.

  Enqueues an Oban job to perform the generation asynchronously.
  The UI will update via Electric sync when subtasks are created.

  ## Path Parameters

  - `task_id` - The ID of the parent task

  ## Response

  Returns immediately with a success status. Subtask creation happens asynchronously.
  """
  @spec generate_subtasks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def generate_subtasks(conn, %{"task_id" => task_id}) do
    case Task.get(task_id) do
      {:ok, task} ->
        enqueue_subtask_generation(conn, task)

      {:error, _} ->
        json_error(conn, :not_found, "Task not found")
    end
  end

  def generate_subtasks(conn, _params) do
    json_error(conn, :bad_request, "task_id is required")
  end

  @doc """
  Gets subtasks for a parent task.

  ## Path Parameters

  - `task_id` - The ID of the parent task

  ## Response

  Returns the list of subtasks ordered by position.
  """
  @spec get_subtasks(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_subtasks(conn, %{"task_id" => task_id}) do
    subtasks =
      Task
      |> Ash.Query.filter(parent_task_id: task_id)
      |> Ash.Query.sort(subtask_position: :asc)
      |> Ash.read!()

    json_ok(conn, %{
      subtasks: Enum.map(subtasks, &serialize_subtask/1)
    })
  end

  def get_subtasks(conn, _params) do
    json_error(conn, :bad_request, "task_id is required")
  end

  @doc """
  Serves an image file for a task.

  Images are stored in the task's working directory and served with
  appropriate content types based on file extension.

  ## Path Parameters

  - `task_id` - The ID of the task
  - `image_id` - The image identifier

  ## Response

  Returns the image file with appropriate Content-Type header.
  """
  @spec get_image(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_image(conn, %{"task_id" => task_id, "image_id" => image_id}) do
    case TaskImageManager.get_image_path(task_id, image_id) do
      {:ok, filepath} ->
        content_type = MIME.from_path(filepath)

        conn
        |> put_resp_content_type(content_type)
        |> send_file(200, filepath)

      {:error, :not_found} ->
        json_error(conn, :not_found, "Image not found")

      {:error, reason} ->
        Logger.error("[TaskController] Failed to get image: #{inspect(reason)}")
        json_error(conn, :internal_server_error, "Failed to retrieve image")
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp enqueue_subtask_generation(conn, task) do
    case %{task_id: task.id}
         |> SubtaskGenerationWorker.new()
         |> Oban.insert() do
      {:ok, _job} ->
        # Update status immediately to show loading state
        Task.set_generation_status(task, %{subtask_generation_status: :generating})
        json_ok(conn, %{message: "Subtask generation started"})

      {:error, error} ->
        Logger.error("[TaskController] Failed to enqueue subtask generation: #{inspect(error)}")
        json_error(conn, :unprocessable_entity, "Failed to start subtask generation")
    end
  end

  defp serialize_subtask(subtask) do
    %{
      id: subtask.id,
      title: subtask.title,
      description: subtask.description,
      priority: subtask.priority,
      column_id: subtask.column_id,
      position: subtask.position,
      subtask_position: subtask.subtask_position,
      agent_status: subtask.agent_status,
      agent_status_message: subtask.agent_status_message
    }
  end
end
