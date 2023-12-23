defmodule Omc.Telegram.CallbackCreditTest do
  alias Omc.Users
  alias Omc.Users.UserInfo
  alias Omc.PaymentFixtures
  use Omc.DataCase
  alias Omc.Telegram.CallbackCredit
  alias Omc.Usages.UsageState
  import PaymentFixtures

  setup %{} do
    %{
      args: %{
        callback_args: [],
        user: %{
          first_name: "some_first_name",
          last_name: "some_last_name",
          language_code: "en",
          user_id: Omc.LedgersFixtures.unique_user_id(),
          user_name: "some_user_name",
          user_type: :telegram
        }
      }
    }
  end

  describe "do_process/1" do
    test "new user - callback_args: []", %{args: args} do
      # no ledger
      assert {:ok, %{payment_requests: [], usage_state: %{ledgers: []}}} =
               CallbackCredit.do_process(args)

      # no UserInfo inserted
      refute Users.get_user_info(args.user)
    end

    test "new user - pay request - callback_args: [amount]", %{args: args} do
      args =
        args
        |> Map.put(:callback_args, ["5"])

      PaymentFixtures.mock_payment_request(args.user |> Map.put(:money, Money.new(500, :USD)))

      # there should exist one payment request
      assert {:ok,
              %{
                payment_requests: [%{money: %{amount: 500, currency: :USD}, paid_sum: nil}],
                usage_state: %{ledgers: []}
              }} = CallbackCredit.do_process(args)

      # user info inserted
      assert %UserInfo{
               user_name: "some_user_name",
               first_name: "some_first_name",
               last_name: "some_last_name",
               language_code: "en"
             } = Users.get_user_info(args.user)
    end
  end

  describe "get_text/1" do
    test "new user - no ledger, no payment request" do
      text =
        %{usage_state: %UsageState{ledgers: []}, payment_requests: []}
        |> CallbackCredit.get_text()

      assert text =~ Money.new(0) |> Money.to_string()
      assert text =~ "no payment request yet"
    end

    test "mix of paid and unpaid", %{args: args} do
      _pr1 = payment_request_fixture(args.user |> Map.put(:money, Money.new(1000)))
      pr2 = payment_request_fixture(args.user |> Map.put(:money, Money.new(2000)))
      pr3 = payment_request_fixture(args.user |> Map.put(:money, Money.new(3000)))
      payment_state_by_callback_fixture(pr2, :done, "1", Money.new(111))
      payment_state_by_callback_fixture(pr2, :done, "2", Money.new(111))
      payment_state_by_callback_fixture(pr3, :done, "1", Money.new(111))

      text =
        args
        |> CallbackCredit.do_process()
        |> then(fn {:ok, new_args} -> new_args end)
        |> CallbackCredit.get_text()

      assert text =~ Money.new(1000) |> Money.to_string()
      assert text =~ Money.new(0) |> Money.to_string()
      assert text =~ Money.new(2000) |> Money.to_string()
      assert text =~ Money.new(222) |> Money.to_string()
      assert text =~ Money.new(3000) |> Money.to_string()
      assert text =~ Money.new(111) |> Money.to_string()
      assert text =~ Money.new(333) |> Money.to_string()
    end
  end
end
