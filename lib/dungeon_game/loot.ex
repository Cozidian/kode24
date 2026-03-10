defmodule DungeonGame.Loot do
  @moduledoc """
  Handles loot drops when a monster is defeated.

  Each drop type is rolled independently:
  - Gold drops when `roller.(2) == 2` (50% chance)
  - An item drops when `roller.(2) == 2` (50% chance)

  Returns a list of drop tuples: `[{:gold, amount}, {:item, %Item{}}]`.
  The list may be empty or contain one or both entries.
  """

  alias DungeonGame.{Dice, Item}

  @doc """
  Rolls for all possible drops from a defeated monster.

  Returns a (possibly empty) list of `{:gold, amount}` and/or `{:item, %Item{}}` tuples.
  """
  @spec roll(map(), Dice.roller()) :: [{:gold, pos_integer()} | {:item, Item.t()}]
  def roll(monster, roller \\ &:rand.uniform/1) do
    gold_drop = if roller.(2) == 2, do: [{:gold, monster.gold}], else: []
    item_drop = if roller.(2) == 2, do: [{:item, Item.random(roller)}], else: []
    gold_drop ++ item_drop
  end
end
