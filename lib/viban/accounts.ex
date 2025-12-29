defmodule Viban.Accounts do
  @moduledoc """
  Domain for user accounts and authentication.

  This domain manages user resources from VCS providers (GitHub, GitLab).
  It handles OAuth-based authentication and user profile data storage.

  ## Resources

  - `Viban.Accounts.User` - User accounts authenticated via VCS providers

  ## Usage

      # Find or create a user from OAuth callback
      Viban.Accounts.User.by_provider_uid(:github, "12345")

      # Get user by ID
      Viban.Accounts.User.get("uuid-here")
  """

  use Ash.Domain

  resources do
    resource Viban.Accounts.User do
      define :get_user, action: :read, get_by: [:id]
      define :get_user_by_provider, action: :by_provider_uid, args: [:provider, :provider_uid]
    end
  end
end
