defmodule VibanWeb.Hologram.Components.GitHubLoginButton do
  use Hologram.Component

  alias VibanWeb.Hologram.UI.{Button, Icon}

  @impl Hologram.Component
  def template do
    ~HOLO"""
    <div $click={action: :show_device_flow_modal, target: "page"}>
      <Button variant="secondary">
        <Icon name="github" size="md" />
        Sign in with GitHub
      </Button>
    </div>
    """
  end
end
