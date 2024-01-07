defmodule Omc.Common.QueueTest do
  use ExUnit.Case, async: true
  alias Omc.Common.Queue

  describe "push/1" do
    test "only adds to items" do
      assert %{value: nil, r_items: [], items: []} = Queue.new()
      assert %{value: nil, r_items: [], items: [1]} = Queue.new() |> Queue.push(1)

      assert %{value: nil, r_items: [], items: [2, 1]} =
               Queue.new() |> Queue.push(1) |> Queue.push(2)

      assert %{value: nil, r_items: [], items: [3, 2, 1]} =
               Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3)
    end
  end

  describe "pop/1" do
    test "empty pop" do
      assert %{value: nil, r_items: [], items: []} = Queue.new() |> Queue.pop()
      assert %{value: nil, r_items: [], items: []} = Queue.new() |> Queue.pop() |> Queue.pop()
    end

    test "single reverse" do
      q = Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3)
      assert %{value: 1, r_items: [2, 3], items: []} = q |> Queue.pop()
      assert %{value: 2, r_items: [3], items: []} = q |> Queue.pop() |> Queue.pop()
      assert %{value: 3, r_items: [], items: []} = q |> Queue.pop() |> Queue.pop() |> Queue.pop()

      assert %{value: nil, r_items: [], items: []} =
               q |> Queue.pop() |> Queue.pop() |> Queue.pop() |> Queue.pop()
    end

    test "double reverse" do
      q = Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3)
      assert %{value: 1, r_items: [2, 3], items: []} = q = q |> Queue.pop()

      assert %{value: 1, r_items: [2, 3], items: [6, 5, 4]} =
               q = q |> Queue.push(4) |> Queue.push(5) |> Queue.push(6)

      assert %{value: 2, r_items: [3], items: [6, 5, 4]} = q = q |> Queue.pop()
      assert %{value: 3, r_items: [], items: [6, 5, 4]} = q = q |> Queue.pop()
      assert %{value: 4, r_items: [5, 6], items: []} = q |> Queue.pop()
    end
  end

  describe "peek/1" do
    test "empty peek" do
      assert %{value: nil, r_items: [], items: []} = Queue.new() |> Queue.peek()
      assert %{value: nil, r_items: [], items: []} = Queue.new() |> Queue.peek() |> Queue.peek()
    end

    test "peek before pop" do
      q = Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3)
      assert %{value: 1, r_items: [1, 2, 3], items: []} = q |> Queue.peek()

      assert %{value: 1, r_items: [1, 2, 3], items: []} =
               q |> Queue.peek() |> Queue.peek() |> Queue.peek()

      assert %{value: 1, r_items: [2, 3], items: []} = q |> Queue.pop()
    end

    test "peek after pop" do
      q = Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3)
      assert %{value: 1, r_items: [1, 2, 3], items: []} = q |> Queue.peek()

      assert %{value: 1, r_items: [2, 3], items: []} = q = q |> Queue.pop()

      assert %{value: 2, r_items: [2, 3], items: []} = q |> Queue.peek()
      assert %{value: 2, r_items: [2, 3], items: []} = q |> Queue.peek() |> Queue.peek()
    end

    test "causing middle reverse" do
      q = Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3)
      assert %{value: 1, r_items: [2, 3], items: []} = q = q |> Queue.pop()

      assert %{value: 1, r_items: [2, 3], items: [6, 5, 4]} =
               q = q |> Queue.push(4) |> Queue.push(5) |> Queue.push(6)

      assert %{value: 3, r_items: [], items: [6, 5, 4]} = q = q |> Queue.pop() |> Queue.pop()
      assert %{value: 4, r_items: [4, 5, 6], items: []} = q |> Queue.peek()
    end
  end

  describe "to_list/1" do
    test "empty queue" do
      assert Queue.new() |> Queue.to_list() == []
    end

    test "non empty queue" do
      assert Queue.new() |> Queue.push(1) |> Queue.push(2) |> Queue.push(3) |> Queue.to_list() ==
               [3, 2, 1]
    end
  end
end
