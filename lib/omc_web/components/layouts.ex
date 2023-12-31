defmodule OmcWeb.Layouts do
  use OmcWeb, :html

  embed_templates "layouts/*"

  attr :id, :string
  attr :users, :list

  def sidebar_active_users(assigns) do
    ~H"""
    <div class="mt-8">
      <h3 class="px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider" id={@id}>
        Active Users
      </h3>
      <div class="mt-1 space-y-1" role="group" aria-labelledby={@id}>
        <%= for user <- @users do %>
          <.link
            navigate={profile_path()}
            class="group flex items-center px-3 py-2 text-base leading-5 font-medium text-gray-600 rounded-md hover:text-gray-900 hover:bg-gray-50"
          >
            <span class="w-2.5 h-2.5 mr-4 bg-indigo-500 rounded-full" aria-hidden="true"></span>
            <span class="truncate">
              <%= user.email %>
            </span>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  attr :id, :string
  attr :current_user, :any
  attr :active_tab, :atom

  def sidebar_nav_links(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= if @current_user do %>
        <.link
          navigate={~p"/servers"}
          class={
            "text-gray-700 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md #{if @active_tab == :servers, do: "bg-gray-200", else: "hover:bg-gray-50"}"
          }
          aria-current={if @active_tab == :servers, do: "true", else: "false"}
        >
          <.icon
            name="hero-x-mark-solid"
            class="text-gray-400 group-hover:text-gray-500 mr-3 flex-shrink-0 h-6 w-6"
          /> My Servers
        </.link>
        <.link
          navigate={~p"/server_accs"}
          class={
            "text-gray-700 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md #{if @active_tab == :server_accs, do: "bg-gray-200", else: "hover:bg-gray-50"}"
          }
          aria-current={if @active_tab == :server_accs, do: "true", else: "false"}
        >
          <.icon
            name="hero-x-mark-solid"
            class="text-gray-400 group-hover:text-gray-500 mr-3 flex-shrink-0 h-6 w-6"
          /> Server Accounts
        </.link>
        <.link
          navigate={~p"/ledgers"}
          class={
            "text-gray-700 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md #{if @active_tab == :ledgers, do: "bg-gray-200", else: "hover:bg-gray-50"}"
          }
          aria-current={if @active_tab == :ledgers, do: "true", else: "false"}
        >
          <.icon
            name="hero-x-mark-solid"
            class="text-gray-400 group-hover:text-gray-500 mr-3 flex-shrink-0 h-6 w-6"
          /> Ledgers
        </.link>
        <.link
          navigate={~p"/payment_requests"}
          class={
            "text-gray-700 hover:text-gray-900 group flex items-center px-2 py-2 text-sm font-medium rounded-md #{if @active_tab == :payment_requests, do: "bg-gray-200", else: "hover:bg-gray-50"}"
          }
          aria-current={if @active_tab == :payment_requests, do: "true", else: "false"}
        >
          <.icon
            name="hero-x-mark-solid"
            class="text-gray-400 group-hover:text-gray-500 mr-3 flex-shrink-0 h-6 w-6"
          /> Payment Requests
        </.link>
      <% else %>
        <.link
          navigate={~p"/users/log_in"}
          class="text-gray-700 hover:text-gray-900 hover:bg-gray-50 group flex items-center px-2 py-2 text-sm font-medium rounded-md"
        >
          <svg
            class="text-gray-400 group-hover:text-gray-500 mr-3 flex-shrink-0 h-6 w-6"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            aria-hidden="true"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
            >
            </path>
          </svg>
          Sign in
        </.link>
      <% end %>
    </div>
    """
  end

  attr :id, :string
  attr :current_user, :any

  def sidebar_account_dropdown(assigns) do
    ~H"""
    <.dropdown id={@id}>
      <!-- <:img src={@current_user.avatar_url} /> -->
      <:title><%= @current_user.email %></:title>
      <:subtitle>@<%= @current_user.email %></:subtitle>
      <!--<:link navigate={profile_path()}>View Profile</:link>-->
      <:link navigate={~p"/users/settings"}>Settings</:link>
      <:link href={~p"/users/log_out"} method={:delete}>Sign out</:link>
    </.dropdown>
    """
  end
end
