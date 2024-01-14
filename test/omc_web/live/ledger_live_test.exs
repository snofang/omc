defmodule OmcWeb.LedgerLiveTest do
  use OmcWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Omc.AccountsFixtures
  import Omc.LedgersFixtures

  defp create_ledger(_) do
    user = user_fixture()
    %{ledger: ledger, ledger_tx: ledger_tx} = ledger_tx_fixture!()
    %{user: user, ledger: ledger, ledger_tx: ledger_tx}
  end

  describe "Index" do
    setup [:create_ledger]

    test "lists all ledgers", %{conn: conn, user: user, ledger: ledger} do
      {:ok, _index_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/ledgers")

      assert html =~ "Listing Ledgers"
      assert html =~ Money.new(ledger.credit, ledger.currency) |> Money.to_string()
      assert html =~ ledger.user_id
      assert html =~ ledger.user_type |> to_string()
      assert html =~ ledger.currency |> to_string()
    end

    test "New Ledger Tx", %{conn: conn, user: user} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/ledgers")

      assert index_live
             |> element("a", "New Ledger Tx")
             |> render_click() =~ "New Ledger Tx"

      assert index_live
             |> form("#ledger-tx-form",
               ledger_tx_aux: %{
                 user_type: "",
                 user_id: "1234567890",
                 currency: :USD,
                 type: :credit,
                 amount: "123.23"
               }
             )
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#ledger-tx-form",
               ledger_tx_aux: %{
                 user_type: :local,
                 user_id: "",
                 currency: :USD,
                 type: :credit,
                 amount: "123.23"
               }
             )
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#ledger-tx-form",
               ledger_tx_aux: %{
                 user_type: :local,
                 user_id: "1234567890",
                 currency: nil,
                 type: :credit,
                 amount: "123.23"
               }
             )
             |> render_change() =~ "can&#39;t be blank"

      index_live
      |> form("#ledger-tx-form",
        ledger_tx_aux: %{
          user_type: :local,
          user_id: "1234567890",
          currency: :EUR,
          type: :credit,
          amount: "246.24"
        }
      )
      |> render_submit()

      assert_patch(index_live, ~p"/ledgers")

      html = render(index_live)
      assert html =~ "Ledger Tx created succesfully."

      assert html =~
               Money.parse!("246.24", :EUR)
               |> Money.to_string()
    end

    test "New Tx", %{conn: conn, user: user, ledger: ledger} do
      {:ok, index_live, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/ledgers")

      assert index_live
             |> element("#ledgers-#{ledger.id} a", "New Tx")
             |> render_click() =~ "New Ledger Tx"

      assert index_live
             |> form("#ledger-tx-form", ledger_tx_aux: %{type: "", amount: "123.23"})
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#ledger-tx-form", ledger_tx_aux: %{type: :credit, amount: "123a.23"})
             |> render_change() =~ "invalid format"

      assert index_live
             |> form("#ledger-tx-form", ledger_tx_aux: %{type: :credit, amount: "123.45"})
             |> render_submit()

      assert_patch(index_live, ~p"/ledgers")

      html = render(index_live)
      assert html =~ "Ledger Tx created succesfully."

      assert html =~
               Money.parse!("123.45", ledger.currency)
               |> Money.add(Money.new(ledger.credit, ledger.currency))
               |> Money.to_string()
    end
  end

  describe "Show" do
    setup [:create_ledger]

    test "displays ledgers", %{conn: conn, user: user, ledger: ledger, ledger_tx: ledger_tx} do
      {:ok, _show_live, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/ledgers/#{ledger}")

      assert html =~ "Show Ledger Detail"
      assert html =~ Money.new(ledger.credit, ledger.currency) |> Money.to_string()
      assert html =~ ledger.user_id
      assert html =~ ledger.user_type |> to_string()
      assert html =~ ledger.currency |> to_string()
      assert html =~ ledger_tx.type |> to_string()
      assert html =~ ledger_tx.context |> to_string()
      assert html =~ ledger_tx.id |> to_string()
    end
  end
end
