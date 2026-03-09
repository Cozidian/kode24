defmodule DungeonGame.Player do
  @moduledoc "Represents the player character."

  defstruct name: "Hero", hp: 100, max_hp: 100, damage: "2d6", armor_class: 14, potions: 2
end
