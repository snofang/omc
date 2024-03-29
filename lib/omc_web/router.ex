defmodule OmcWeb.Router do
  use OmcWeb, :router

  import OmcWeb.User.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {OmcWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", OmcWeb do
    pipe_through(:browser)

    import Phoenix.Controller

    get("/", RootRedirector, nil)
    # get "/", PageController, :home
  end

  scope "/api/payment", OmcWeb do
    pipe_through(:api)
    post("/:ipg", PaymentController, :callback)
  end

  scope "/admin" do
    import Phoenix.LiveDashboard.Router
    pipe_through([:browser, :require_authenticated_user])

    live_dashboard("/dashboard", metrics: OmcWeb.Telemetry)
    forward("/mailbox", Plug.Swoosh.MailboxPreview)
  end

  ## Authentication routes
  scope "/", OmcWeb.User, as: :user do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{OmcWeb.User.UserAuth, :redirect_if_user_is_authenticated}] do
      # live("/users/register", UserRegistrationLive, :new)
      live("/users/log_in", UserLoginLive, :new)
      live("/users/reset_password", UserForgotPasswordLive, :new)
      live("/users/reset_password/:token", UserResetPasswordLive, :edit)
    end

    post("/users/log_in", UserSessionController, :create)
  end

  scope "/", OmcWeb, as: :user do
    pipe_through([:browser, :require_authenticated_user])

    live_session :require_authenticated_user,
      on_mount: [{OmcWeb.User.UserAuth, :ensure_authenticated}, OmcWeb.Nav] do
      live("/servers", ServerLive.Index, :index)
      live("/servers/new", ServerLive.Index, :new)
      live("/servers/:id/edit", ServerLive.Index, :edit)
      live("/servers/:id", ServerLive.Show, :show)
      live("/servers/:id/show/edit", ServerLive.Show, :edit)
      live("/servers/:id/task", ServerLive.Task, :task)

      live("/server_accs", ServerAccLive.Index, :index)
      live("/server_accs/new", ServerAccLive.Index, :new)
      live("/server_accs/new_batch", ServerAccLive.Index, :new_batch)
      live("/server_accs/:id", ServerAccLive.Show, :show)

      live("/payment_requests", PaymentRequestLive.Index, :index)
      live("/payment_requests/:id", PaymentRequestLive.Show, :show)

      live("/ledgers", LedgerLive.Index, :index)
      live("/ledgers/:id", LedgerLive.Show, :show)
      # live("/ledgers/:id/new_tx", LedgerLive.Index, :new_tx)

      live("/users/settings", User.UserSettingsLive, :edit)
      live("/users/settings/confirm_email/:token", User.UserSettingsLive, :confirm_email)
    end
  end

  scope "/", OmcWeb.User, as: :user do
    pipe_through([:browser])

    delete("/users/log_out", UserSessionController, :delete)

    live_session :current_user,
      on_mount: [{OmcWeb.User.UserAuth, :mount_current_user}, OmcWeb.Nav] do
      live("/users/confirm/:token", UserConfirmationLive, :edit)
      live("/users/confirm", UserConfirmationInstructionsLive, :new)
    end
  end
end
