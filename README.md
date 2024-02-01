# OMC

This is a one stop solution for managing many distributed instances of [OpenVPN](https://openvpn.net/) and sell their accounts.

Created with the followings:
- [Elixir](https://elixir-lang.org) 
- [Phoenix](https://www.phoenixframework.org) 
- [LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [PostgreSQL](https://www.postgresql.org)
- [Ansible](https://www.ansible.com/)

## Features
- **Installs & configures OpenVPN on remote machines:** The only thing that is required is a RSA based SSH access with sudo privilege for a hard coded user named `omc`. Following on by a button click, It will install OVPN on the target machine and sync back its data on the OMC server.

- **Manages Accounts:**  It gives full control over accounts; Accounts files(.ovpn access files) created remotely on the target worker machine and get synced back to the OMC server. Removing accounts is as simple as marking an account in the server for deactivation and then syncing with the worker machine which can be automatic/manual.

- **Automatic Accounts Provisioning:** Keeps the number of available accounts on a specific worker server, at a maximum configured number. For example, at the moment of an account removal(which can be caused by a end user or from the backend management console), a new job will be queued to delete specified account and also create new one in place to keep the worker up and running with the specified max account numbers.

- **Point Of Sale:** Via Telegram bot, all accounts on all worker servers grouped by tags and price, are available for sale.

- **Billings:** It has a very simple time based billing system which lets users to have the benefits of *PAY-AS-YOU-GO*.

- **Payments:** Supports two crypto currency payment providers: [OxaPay](https://oxapay.com) and [NOWPayments](https://nowpayments.io).

## Requirements
You need to have **Elixir v1.14**, **PostgreSQL**, and **Ansible** installed.

## Installation instructions
To start OMC:

  1. Install dependencies with `mix deps.get`
  2. Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  3. Run seeds to create admin user and initial prices with `mix run priv/repo/seeds.exs`
  4. Configure at least the followings env variables to connect it to the outside(use any [awesome-tunneling](https://github.com/anderspitman/awesome-tunneling)):
  ```
  OMC_BASE_URL=https://example.com
  OMC_TELEGRAM_TOKEN=replace_me
  OMC_TELEGRAM_HOST=telegram.example.com # Please note thet this should be without scheme.
  OMC_IPGS_RETURNURL=https://t.me/your_awesome_bot_name
  ```

  4. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
For further config options take a look at [env.sh.eex](https://github.com/snofang/omc/blob/main/rel/env.sh.eex).

## Contributing
This is a working software and acts as a proof of concept. There are lots of rooms for improvements and extensions. Any contributions are welcome.

