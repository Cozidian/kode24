defmodule DungeonGame.Loot do
  @moduledoc """
  Handles loot drops when a monster is defeated.

  Normal fights drop only gold (50% chance).
  Elite fights additionally offer a choice of items/potions via `elite_choices/1`.
  """

  alias DungeonGame.{Dice, Item}

  @doc """
  Rolls for gold drop from a normal fight.
  Returns `[{:gold, amount}]` (50% chance) or `[]`.
  """
  @spec roll(map(), Dice.roller()) :: [{:gold, pos_integer()}]
  def roll(monster, roller \\ &:rand.uniform/1) do
    if roller.(2) == 2, do: [{:gold, monster.gold}], else: []
  end

  @doc """
  Generates 3 elite reward choices: 2 random items + 1 potion.
  The player picks one after defeating an elite monster.
  """
  @spec elite_choices(Dice.roller()) :: [{:item, Item.t()} | {:potion, pos_integer()}]
  def elite_choices(roller \\ &:rand.uniform/1) do
    [
      {:item, Item.random(roller)},
      {:item, Item.random(roller)},
      {:potion, 2}
    ]
  end
end
