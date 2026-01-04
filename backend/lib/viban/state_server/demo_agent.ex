defmodule Viban.StateServer.DemoAgent do
  @moduledoc """
  A simple demo agent that holds text state.
  Used to demonstrate StateServer persistence and Electric sync.
  """

  use Viban.StateServer.Core, restart: :permanent

  @type state :: %__MODULE__{
          text: String.t()
        }

  defstruct text: ""

  @agent_id "demo-agent"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_text do
    GenServer.call(__MODULE__, :get_text)
  end

  def set_text(text) do
    GenServer.call(__MODULE__, {:set_text, text})
  end

  @impl true
  def init(_args) do
    default_state = %__MODULE__{text: "Hello from DemoAgent!"}
    state = Viban.StateServer.Core.init_state(__MODULE__, default_state, @agent_id)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_text, _from, state) do
    {:reply, state.text, state}
  end

  @impl true
  def handle_call({:set_text, text}, _from, state) do
    new_state = update_state(state, text: text)
    {:reply, :ok, new_state}
  end
end
