defmodule VibanWeb.Hologram.UI do
  @moduledoc """
  Viban Design System for Hologram.

  This module provides a consistent set of UI primitives for building
  the Viban application. Import the components you need in your pages
  and components.

  ## Available Components

  ### Icons
  - `VibanWeb.Hologram.UI.Icon` - SVG icon component with named icons

  ### Form Elements
  - `VibanWeb.Hologram.UI.Button` - Buttons with variants (primary, secondary, ghost, danger, icon)
  - `VibanWeb.Hologram.UI.Input` - Text inputs and textareas

  ### Feedback
  - `VibanWeb.Hologram.UI.LoadingSpinner` - SVG-based loading spinners
  - `VibanWeb.Hologram.UI.Toast` - Stackable toast notifications
  - `VibanWeb.Hologram.UI.Tooltip` - Hover tooltips
  - `VibanWeb.Hologram.UI.Badge` - Status badges/tags
  - `VibanWeb.Hologram.UI.Alert` - Alert messages

  ### Layout
  - `VibanWeb.Hologram.UI.Modal` - Modal dialogs
  - `VibanWeb.Hologram.UI.ModalFooter` - Modal footer with action buttons
  - `VibanWeb.Hologram.UI.Card` - Card containers
  - `VibanWeb.Hologram.UI.CardHeader` - Card header section
  - `VibanWeb.Hologram.UI.CardBody` - Card body section

  ### Navigation
  - `VibanWeb.Hologram.UI.Dropdown` - Dropdown menus
  - `VibanWeb.Hologram.UI.DropdownItem` - Dropdown menu item
  - `VibanWeb.Hologram.UI.DropdownDivider` - Dropdown divider
  - `VibanWeb.Hologram.UI.DropdownHeader` - Dropdown header section

  ### User
  - `VibanWeb.Hologram.UI.Avatar` - User avatar with fallback initials

  ## Usage

  In your Hologram page or component:

      defmodule VibanWeb.Hologram.Pages.MyPage do
        use Hologram.Page

        alias VibanWeb.Hologram.UI.{Button, Input, Modal, Icon, LoadingSpinner}

        # ... template using components
      end

  ## Design Tokens

  ### Colors
  - Brand: `brand-500`, `brand-600`, `brand-700`
  - Gray scale: `gray-300` to `gray-950`
  - Status: `green`, `yellow`, `red`, `blue`, `purple`

  ### Sizes
  Most components support: `xs`, `sm`, `md`, `lg`, `xl`

  ### Variants
  - Buttons: `primary`, `secondary`, `ghost`, `danger`, `icon`
  - Badges: `default`, `success`, `warning`, `error`, `info`, `purple`, `brand`
  - Alerts: `info`, `success`, `warning`, `error`

  ## Examples

  ### Button with loading state

      <Button variant="primary" loading={@saving}>
        {%if @saving}Saving...{%else}Save{/if}
      </Button>

  ### Form with validation

      <Input
        label="Email"
        type="email"
        value={@email}
        error={@errors[:email]}
        $input="update_email"
      />

  ### Modal with footer

      <Modal is_open={@show_modal} title="Confirm Action" on_close="close_modal">
        <p class="text-gray-300">Are you sure you want to proceed?</p>
        <ModalFooter>
          <Button variant="ghost" $click="close_modal">Cancel</Button>
          <Button variant="danger" $click="confirm">Delete</Button>
        </ModalFooter>
      </Modal>

  ### Dropdown menu

      <div class="relative">
        <Button variant="icon" $click="toggle_menu">
          <Icon name="settings" />
        </Button>
        <Dropdown is_open={@menu_open}>
          <DropdownHeader>
            <p class="text-sm font-medium text-white">{@user.name}</p>
          </DropdownHeader>
          <DropdownItem icon="edit" $click="edit">Edit</DropdownItem>
          <DropdownDivider />
          <DropdownItem icon="logout" $click="logout">Sign out</DropdownItem>
        </Dropdown>
      </div>
  """

  @doc """
  Convenience function to generate common utility aliases for UI components.
  Returns a list of alias statements for use in module definitions.
  """
  defmacro __using__(_opts) do
    quote do
      alias VibanWeb.Hologram.UI.{
        Icon,
        Button,
        Input,
        LoadingSpinner,
        Toast,
        Tooltip,
        Badge,
        Alert,
        Avatar,
        Modal,
        ModalFooter,
        Card,
        CardHeader,
        CardBody,
        Dropdown,
        DropdownItem,
        DropdownDivider,
        DropdownHeader
      }
    end
  end
end
