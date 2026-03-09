defmodule DungeonGame.Monster do
  @moduledoc """
  Monster definitions and round-based scaling.

  Monsters advance through four tiers every three rounds:
    Rounds  1–3  → Goblin
    Rounds  4–6  → Orc
    Rounds  7–9  → Troll
    Rounds 10+   → Dragon

  Within each tier, base HP grows by 5 per round to keep pressure increasing.
  """

  defstruct [:name, :hp, :max_hp, :damage, :armor_class]

  @types [
    %{name: "Goblin", base_hp: 12, damage: "1d6", armor_class: 9},
    %{name: "Orc",    base_hp: 25, damage: "1d8", armor_class: 11},
    %{name: "Troll",  base_hp: 45, damage: "2d6", armor_class: 13},
    %{name: "Dragon", base_hp: 70, damage: "2d8", armor_class: 15}
  ]

  @doc """
  Spawns a monster scaled to the given `round` number.
  """
  @spec for_round(pos_integer()) :: %__MODULE__{}
  def for_round(round) do
    type_index = min(div(round - 1, 3), length(@types) - 1)
    type = Enum.at(@types, type_index)
    hp = type.base_hp + round * 5

    %__MODULE__{
      name: type.name,
      hp: hp,
      max_hp: hp,
      damage: type.damage,
      armor_class: type.armor_class
    }
  end
end
