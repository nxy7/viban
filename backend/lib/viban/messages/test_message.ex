defmodule Viban.Messages.TestMessage do
  @moduledoc """
  Test message resource for verifying real-time sync functionality.

  This resource provides a simple message that can be randomized or retrieved,
  useful for testing the Phoenix Sync connection between frontend and backend.
  """

  use Ash.Resource,
    domain: Viban.Messages,
    data_layer: AshPostgres.DataLayer

  alias Viban.Messages.TestMessage.Actions

  postgres do
    table "test_messages"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :text, :string do
      allow_nil? false
      default "Hello from Viban!"
      description "The message content"
    end

    timestamps()
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:text]
      primary? true
    end

    update :update do
      accept [:text]
      primary? true
    end

    action :randomize, :struct do
      constraints instance_of: __MODULE__
      description "Select a random message and update or create"
      run Actions.Randomize
    end

    action :get_or_create, :struct do
      constraints instance_of: __MODULE__
      description "Get existing message or create default one"
      run Actions.GetOrCreate
    end
  end

  code_interface do
    define :create, args: [:text]
    define :read
    define :update, args: [:text]
    define :randomize
    define :get_or_create
  end
end
