defmodule DungeonGame.Player do
  @moduledoc "Represents the player character."

  defstruct name: "Hero", hp: 20, max_hp: 20, damage: "1d4", armor_class: 14, potions: 2
end
