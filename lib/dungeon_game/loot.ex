defmodule DungeonGame.Loot do
  @moduledoc """
  Handles loot drops when a monster is defeated.

  Each drop type is rolled independently:
  - Gold drops when `roller.(2) == 2` (50% chance)
  - An item drops when `roller.(2) == 2` (50% chance)
  - A potion drops when `roller.(2) == 2` (50% chance)

  Returns a list of drop tuples. The list may be empty or contain any combination of entries.
  """

  alias DungeonGame.{Dice, Item}

  @doc """
  Rolls for all possible drops from a defeated monster.

  Returns a (possibly empty) list of `{:gold, amount}` and/or `{:item, %Item{}}` tuples.
  """
  @spec roll(map(), Dice.roller()) :: [{:gold, pos_integer()} | {:item, Item.t()} | {:potion, 1}]
  def roll(monster, roller \\ &:rand.uniform/1) do
    gold_drop = if roller.(2) == 2, do: [{:gold, monster.gold}], else: []
    item_drop = if roller.(2) == 2, do: [{:item, Item.random(roller)}], else: []
    potion_drop = if roller.(2) == 2, do: [{:potion, 1}], else: []
    gold_drop ++ item_drop ++ potion_drop
  end
end
