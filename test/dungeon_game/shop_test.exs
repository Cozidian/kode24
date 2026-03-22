defmodule DungeonGame.ShopTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Card, Item, Shop}

  defp always(n), do: fn _sides -> n end

  describe "generate/2" do
    test "returns exactly 4 items" do
      assert length(Shop.generate(:warrior, always(1))) == 4
    end

    test "all entries are {type, payload, price} tuples" do
      choices = Shop.generate(:warrior, always(1))

      Enum.each(choices, fn entry ->
        assert match?({type, _payload, price} when is_atom(type) and is_integer(price), entry)
      end)
    end

    test "includes exactly 2 items" do
      choices = Shop.generate(:warrior, always(1))
      item_count = Enum.count(choices, &match?({:item, _, _}, &1))
      assert item_count == 2
    end

    test "includes exactly 1 potion bundle" do
      choices = Shop.generate(:warrior, always(1))
      potion_count = Enum.count(choices, &match?({:potion, _, _}, &1))
      assert potion_count == 1
    end

    test "includes exactly 1 card" do
      choices = Shop.generate(:warrior, always(1))
      card_count = Enum.count(choices, &match?({:card, _, _}, &1))
      assert card_count == 1
    end

    test "item payloads are %Item{} structs" do
      choices = Shop.generate(:mage, always(2))

      choices
      |> Enum.filter(&match?({:item, _, _}, &1))
      |> Enum.each(fn {:item, item, _price} ->
        assert %Item{} = item
      end)
    end

    test "card payloads are %Card{} structs from the correct class reward pool" do
      choices = Shop.generate(:rogue, always(1))

      {:card, card, _price} = Enum.find(choices, &match?({:card, _, _}, &1))
      assert %Card{} = card
      assert card in Card.reward_pool(:rogue)
    end

    test "item prices are 8/15/25 gold for bonus +1/+2/+3" do
      choices = Shop.generate(:warrior, always(1))

      choices
      |> Enum.filter(&match?({:item, _, _}, &1))
      |> Enum.each(fn {:item, item, price} ->
        expected = Shop.item_price(item)
        assert price == expected
      end)
    end

    test "item_price/1 returns 8 for +1, 15 for +2, 25 for +3" do
      assert Shop.item_price(%Item{type: :weapon, name: "Dagger", bonus: 1}) == 8
      assert Shop.item_price(%Item{type: :weapon, name: "Short Sword", bonus: 2}) == 15
      assert Shop.item_price(%Item{type: :weapon, name: "Long Sword", bonus: 3}) == 25
    end
  end
end
