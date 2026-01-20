defmodule Viban.Kanban.MessageTest do
  @moduledoc """
  Tests for the Message resource including:
  - Message CRUD operations
  - Sequence auto-increment
  - Status transitions
  """
  use Viban.DataCase, async: true

  alias Viban.Kanban.Board
  alias Viban.Kanban.Column
  alias Viban.Kanban.Message
  alias Viban.Kanban.Task

  describe "Message resource" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})
      {:ok, columns} = Column.read()
      column = Enum.find(columns, &(&1.board_id == board.id))

      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: column.id
        })

      {:ok, task: task, user: user}
    end

    test "can create a user message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "Hello, AI!"
        })

      assert message.task_id == task.id
      assert message.role == :user
      assert message.content == "Hello, AI!"
      assert message.status == :pending
      assert message.sequence == 1
    end

    test "can create an assistant message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Hello! How can I help you?"
        })

      assert message.role == :assistant
    end

    test "can create a system message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :system,
          content: "You are a helpful assistant."
        })

      assert message.role == :system
    end

    test "auto-increments sequence", %{task: task} do
      {:ok, msg1} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "First message"
        })

      {:ok, msg2} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Second message"
        })

      {:ok, msg3} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "Third message"
        })

      assert msg1.sequence == 1
      assert msg2.sequence == 2
      assert msg3.sequence == 3
    end

    test "can complete a message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Processing...",
          status: :processing
        })

      {:ok, completed} =
        Message.complete(message, %{
          content: "Complete response"
        })

      assert completed.status == :completed
      assert completed.content == "Complete response"
    end

    test "can fail a message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Processing...",
          status: :processing
        })

      {:ok, failed} =
        Message.fail(message, %{
          metadata: %{"error" => "API error"}
        })

      assert failed.status == :failed
      assert failed.metadata["error"] == "API error"
    end

    test "can get messages for a task", %{task: task} do
      {:ok, _msg1} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "First"
        })

      {:ok, _msg2} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Second"
        })

      {:ok, messages} = Message.for_task(task.id)

      assert length(messages) == 2
      assert Enum.at(messages, 0).content == "First"
      assert Enum.at(messages, 1).content == "Second"
    end

    test "for_task returns messages ordered by sequence", %{task: task} do
      # Create messages out of order by updating sequences manually via DB
      {:ok, _msg1} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "First"
        })

      {:ok, _msg2} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Second"
        })

      {:ok, _msg3} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "Third"
        })

      {:ok, messages} = Message.for_task(task.id)

      # Should be ordered by sequence
      sequences = Enum.map(messages, & &1.sequence)
      assert sequences == Enum.sort(sequences)
    end

    test "can delete a message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :user,
          content: "To be deleted"
        })

      :ok = Message.destroy(message)

      {:ok, messages} = Message.for_task(task.id)
      assert Enum.find(messages, &(&1.id == message.id)) == nil
    end

    test "can store metadata", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Hello",
          metadata: %{
            provider: "claude",
            model: "claude-3-opus",
            tokens_used: 100
          }
        })

      assert message.metadata["provider"] == "claude"
      assert message.metadata["model"] == "claude-3-opus"
      assert message.metadata["tokens_used"] == 100
    end

    test "can append content to a message", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Hello"
        })

      {:ok, updated} = Message.append_content(message, "World")

      assert updated.content == "HelloWorld"
    end

    test "can append content multiple times", %{task: task} do
      {:ok, message} =
        Message.create(%{
          task_id: task.id,
          role: :assistant,
          content: "Start"
        })

      {:ok, updated1} = Message.append_content(message, "-middle")
      {:ok, updated2} = Message.append_content(updated1, "-end")

      assert updated2.content == "Start-middle-end"
    end
  end

  describe "Task agent_status fields" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, board} = Board.create(%{name: "Test Board", description: "Test", user_id: user.id})
      {:ok, columns} = Column.read()
      column = Enum.find(columns, &(&1.board_id == board.id))

      {:ok, task} =
        Task.create(%{
          title: "Test Task",
          column_id: column.id
        })

      {:ok, task: task, user: user}
    end

    test "task starts with idle agent_status", %{task: task} do
      assert task.agent_status == :idle
      assert task.agent_status_message == nil
    end

    test "can update agent_status", %{task: task} do
      {:ok, updated} =
        Task.update_agent_status(task, %{
          agent_status: :thinking,
          agent_status_message: "Processing your request..."
        })

      assert updated.agent_status == :thinking
      assert updated.agent_status_message == "Processing your request..."
    end

    test "can set agent_status to error", %{task: task} do
      {:ok, updated} =
        Task.update_agent_status(task, %{
          agent_status: :error,
          agent_status_message: "API rate limit exceeded"
        })

      assert updated.agent_status == :error
      assert updated.agent_status_message == "API rate limit exceeded"
    end

    test "can clear agent_status_message", %{task: task} do
      {:ok, _} =
        Task.update_agent_status(task, %{
          agent_status: :thinking,
          agent_status_message: "Thinking..."
        })

      {:ok, updated} =
        Task.update_agent_status(task, %{
          agent_status: :idle,
          agent_status_message: nil
        })

      assert updated.agent_status == :idle
      assert updated.agent_status_message == nil
    end
  end
end
