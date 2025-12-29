defmodule Viban.Accounts.User do
  @moduledoc """
  User resource representing an authenticated user from a VCS provider.

  Users authenticate via OAuth with their VCS provider (GitHub or GitLab).
  The user's identity is tied to their provider account, allowing them
  to access their repositories for Kanban board integration.

  ## Supported Providers

  - `:github` - GitHub OAuth authentication
  - `:gitlab` - GitLab OAuth authentication

  ## Security

  The `access_token` attribute is marked as sensitive and will not be
  included in logs or error messages.

  ## Identity

  Users are uniquely identified by the combination of `provider` and
  `provider_uid`. This allows the same person to have separate accounts
  for different VCS providers if needed.
  """

  use Ash.Resource,
    domain: Viban.Accounts,
    data_layer: AshPostgres.DataLayer

  @type provider :: :github | :gitlab

  postgres do
    table "users"
    repo Viban.Repo
  end

  attributes do
    uuid_primary_key :id

    # Provider identity - required for authentication
    attribute :provider, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:github, :gitlab]
      description "VCS provider used for authentication"
    end

    attribute :provider_uid, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
      description "Unique user identifier from the VCS provider"
    end

    attribute :provider_login, :string do
      allow_nil? false
      public? true
      constraints max_length: 255
      description "Username/login from the VCS provider"
    end

    # Profile information - optional, synced from provider
    attribute :name, :string do
      public? true
      constraints max_length: 255
      description "Display name from the VCS provider"
    end

    attribute :email, :string do
      public? true
      constraints max_length: 320
      description "Email address (may be nil if user set it private)"
    end

    attribute :avatar_url, :string do
      public? true
      constraints max_length: 2048
      description "URL to the user's avatar image"
    end

    # Authentication credentials - sensitive
    attribute :access_token, :string do
      allow_nil? false
      sensitive? true
      description "OAuth access token for API calls to the VCS provider"
    end

    attribute :token_expires_at, :utc_datetime do
      description "Token expiration timestamp (nil if token doesn't expire)"
    end

    timestamps()
  end

  identities do
    identity :unique_provider_uid, [:provider, :provider_uid] do
      message "A user with this provider account already exists"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Create a new user from OAuth authentication"

      accept [
        :provider,
        :provider_uid,
        :provider_login,
        :name,
        :email,
        :avatar_url,
        :access_token,
        :token_expires_at
      ]

      primary? true
    end

    update :update do
      description "Update user profile data (typically after OAuth refresh)"

      accept [
        :provider_login,
        :name,
        :email,
        :avatar_url,
        :access_token,
        :token_expires_at
      ]

      primary? true
    end

    update :refresh_token do
      description "Update only the access token and expiration"
      accept [:access_token, :token_expires_at]
    end

    read :by_provider_uid do
      description "Look up a user by their VCS provider identity"

      argument :provider, :atom do
        allow_nil? false
        constraints one_of: [:github, :gitlab]
      end

      argument :provider_uid, :string do
        allow_nil? false
        constraints max_length: 255
      end

      get? true
      filter expr(provider == ^arg(:provider) and provider_uid == ^arg(:provider_uid))
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :refresh_token
    define :by_provider_uid, args: [:provider, :provider_uid]
    define :get, action: :read, get_by: [:id]
  end
end
