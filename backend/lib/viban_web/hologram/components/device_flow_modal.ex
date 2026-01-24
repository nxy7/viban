defmodule VibanWeb.Hologram.Components.DeviceFlowModal do
  use Hologram.Component

  alias Viban.Accounts.User
  alias Viban.Auth.DeviceFlow
  alias VibanWeb.Hologram.UI.{Button, LoadingSpinner, Modal, Tooltip}

  prop :is_open, :boolean, default: false
  prop :status, :atom, default: :idle
  prop :user_code, :string, default: nil
  prop :verification_uri, :string, default: nil
  prop :error, :string, default: nil

  @impl Hologram.Component
  def init(_props, component, server) do
    {component, server}
  end

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <Modal
      is_open={@is_open}
      title="Sign in with GitHub"
      on_close="close_device_flow_modal"
      close_target="page"
      size="sm"
    >
      {%if @status == :loading || @status == :idle}
        <div class="flex flex-col items-center py-8">
          <LoadingSpinner size="lg" />
          <p class="text-gray-400 mt-4">Initializing GitHub login...</p>
        </div>
      {/if}

      {%if @status == :error}
        <div class="text-center py-8">
          <h3 class="text-lg font-medium text-white mb-2">Authentication Failed</h3>
          <p class="text-gray-400 mb-4">{@error}</p>
          <div $click={action: :retry_auth, target: "page"}>
            <Button variant="primary">
              Try Again
            </Button>
          </div>
        </div>
      {/if}

      {%if @status == :success}
        <div class="text-center py-8">
          <h3 class="text-lg font-medium text-white mb-2">Successfully signed in!</h3>
          <p class="text-gray-400">Redirecting...</p>
        </div>
      {/if}

      {%if @status == :pending}
        <div class="text-center">
          <p class="text-gray-400 mb-6">
            Visit <a href={@verification_uri} target="_blank" class="text-brand-500 hover:text-brand-400">{@verification_uri}</a> and enter this code:
          </p>
          <div class="relative mb-6">
            <Tooltip text="Click to copy code">
              <button
                class="w-full bg-gray-800 border-2 border-gray-700 hover:border-brand-500 rounded-lg p-4 transition-colors group"
                data-copy-text={@user_code}
                onclick="navigator.clipboard.writeText(this.dataset.copyText).then(VibanToast.success.bind(null, 'Code copied!'))"
              >
                <span class="text-3xl font-mono font-bold text-white tracking-widest">{@user_code}</span>
              </button>
            </Tooltip>
          </div>
          <div class="flex items-center justify-center gap-2 text-gray-400">
            <LoadingSpinner size="sm" />
            <span>Waiting for authorization...</span>
          </div>
        </div>
      {/if}
    </Modal>
    """
  end

  def action(:close_modal, _params, component) do
    component
    |> put_command(:cancel_flow, [])
    |> put_action(name: :hide_device_flow_modal, params: %{}, target: :page)
  end

  def action(:start_auth, _params, component) do
    component
    |> put_action(name: :set_device_flow_status, params: %{status: :loading}, target: :page)
    |> put_command(:request_device_code, %{})
  end

  def action(:retry, _params, component) do
    component
    |> put_action(name: :set_device_flow_status, params: %{status: :loading}, target: :page)
    |> put_command(:request_device_code, %{})
  end

  def command(:request_device_code, _params, component, server) do
    case DeviceFlow.request_device_code() do
      {:ok, data} ->
        server =
          server
          |> put_session(:device_code, data.device_code)
          |> put_session(:device_code_expires_at, System.system_time(:second) + data.expires_in)
          |> put_session(:device_poll_interval, data.interval)

        component =
          component
          |> put_action(name: :set_device_code, params: %{
            user_code: data.user_code,
            verification_uri: data.verification_uri,
            device_code: data.device_code,
            interval: data.interval
          }, target: :page)
          |> put_command(:poll_for_token, %{device_code: data.device_code, interval: data.interval})

        {component, server}

      {:error, reason} ->
        component = put_action(component, name: :set_device_flow_error, params: %{error: reason}, target: :page)
        {component, server}
    end
  end

  def command(:poll_for_token, %{device_code: device_code, interval: interval}, component, server) do
    :timer.sleep(interval * 1000)

    case DeviceFlow.poll_for_token(device_code) do
      {:ok, access_token} ->
        handle_successful_auth(component, server, access_token)

      :pending ->
        component = put_command(component, :poll_for_token, %{device_code: device_code, interval: interval})
        {component, server}

      :slow_down ->
        new_interval = interval + 5
        component = put_command(component, :poll_for_token, %{device_code: device_code, interval: new_interval})
        {component, server}

      {:error, reason} ->
        component = put_action(component, name: :set_device_flow_error, params: %{error: reason}, target: :page)
        {component, server}
    end
  end

  def command(:cancel_flow, _params, component, server) do
    server =
      server
      |> delete_session(:device_code)
      |> delete_session(:device_code_expires_at)
      |> delete_session(:device_poll_interval)

    {component, server}
  end

  defp handle_successful_auth(component, server, access_token) do
    case DeviceFlow.get_user_info(access_token) do
      {:ok, user_info} ->
        user_params = Map.put(user_info, :access_token, access_token)

        case find_or_create_user(user_params) do
          {:ok, user} ->
            server =
              server
              |> delete_session(:device_code)
              |> delete_session(:device_code_expires_at)
              |> delete_session(:device_poll_interval)
              |> put_session(:user_id, user.id)
              |> put_cookie("viban_user_id", user.id, max_age: 60 * 60 * 24 * 30)  # 30 days

            component = put_action(component, name: :auth_success, params: %{user: serialize_user(user)}, target: :page)
            {component, server}

          {:error, _reason} ->
            component = put_action(component, name: :set_device_flow_error, params: %{error: "Failed to create user account"}, target: :page)
            {component, server}
        end

      {:error, reason} ->
        component = put_action(component, name: :set_device_flow_error, params: %{error: reason}, target: :page)
        {component, server}
    end
  end

  defp find_or_create_user(%{provider: provider, provider_uid: provider_uid} = params) do
    case User.by_provider_uid(provider, provider_uid) do
      {:ok, nil} ->
        User.create(params)

      {:ok, user} ->
        update_params = Map.drop(params, [:provider, :provider_uid])
        User.update(user, update_params)

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
          User.create(params)
        else
          {:error, errors}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      avatar_url: user.avatar_url,
      provider: user.provider,
      provider_login: user.provider_login
    }
  end
end
