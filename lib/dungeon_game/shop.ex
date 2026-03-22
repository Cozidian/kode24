defmodule DungeonGame.Shop do
  @moduledoc """
  Generates shop inventory for a merchant node.

  Each shop offers 4 purchasable items:
  - 2 random equipment items (priced by bonus tier)
  - 1 potion bundle (2 potions for 10 gold)
  - 1 random card from the class reward pool (20 gold)

  Inventory entries: `{:item, %Item{}, price}` | `{:potion, count, price}` | `{:card, %Card{}, price}`
  """

  alias DungeonGame.{Card, Dice, Item}

  @potion_price 10
  @card_price 20

  @doc "Generates 4 shop entries for the given class."
  @spec generate(atom(), Dice.roller()) :: [{:item | :potion | :card, term(), pos_integer()}]
  def generate(class, roller \\ &:rand.uniform/1) do
    item1 = Item.random(roller)
    item2 = Item.random(roller)
    card = pick_card(class, roller)

    [
      {:item, item1, item_price(item1)},
      {:item, item2, item_price(item2)},
      {:potion, 2, @potion_price},
      {:card, card, @card_price}
    ]
  end

  @doc "Returns the gold price for an item based on its bonus tier."
  @spec item_price(%Item{}) :: pos_integer()
  def item_price(%Item{bonus: 1}), do: 8
  def item_price(%Item{bonus: 2}), do: 15
  def item_price(%Item{bonus: 3}), do: 25

  defp pick_card(class, roller) do
    pool = Card.reward_pool(class)
    Enum.at(pool, rem(roller.(length(pool)), length(pool)))
  end
end
