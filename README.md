# OMC
OMC (OpenVPN Management Console) is a centralized platform designed to efficiently manage multiple [OpenVPN](https://openvpn.net/) nodes deployed across diverse locations or networks. It provides administrators with a unified interface for configuring, administering, and ensuring the security of these nodes, streamlining the management process and maintaining consistency across the distributed infrastructure. Additionally, OMC integrates with a Telegram bot to facilitate the sale and provisioning of user accounts.

Created with the followings:
- [Elixir](https://elixir-lang.org) 
- [Phoenix](https://www.phoenixframework.org) 
- [LiveView](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html)
- [PostgreSQL](https://www.postgresql.org)
- [Ansible](https://www.ansible.com/)

## Features
##### Effortless Deployment:
- Installs and configures OpenVPN on remote machines with a single click.
- Requires only RSA-based SSH access with sudo privileges for a designated user named 'omc.'

##### Account Management:
- Full control over accounts, creating .ovpn access files remotely on the target worker machine.
- Seamless syncing of account files back to the OMC server.
- Deactivation of accounts with a simple server-side action, offering both automatic and manual options.

##### Automatic Accounts Provisioning:
- Maintains a configured maximum number of available accounts on a specific worker server.
- Automatically queues jobs to delete specified accounts and create new ones to maintain the maximum account numbers.

##### Point Of Sale (POS) via Telegram:
- Accounts on all worker servers are grouped by tags and price for sale.
- Enables easy and secure transactions through a Telegram bot.

##### Billing System:
- Simple time-based billing system for users, following a PAY-AS-YOU-GO model.

##### Cryptocurrency Payments:
- Supports two crypto currency payment providers: [OxaPay](https://oxapay.com) and [NOWPayments](https://nowpayments.io).

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
OMC is a working proof of concept, open to continuous improvements and extensions. Contributions from the community are encouraged, shaping OMC into a more robust and versatile solution.

