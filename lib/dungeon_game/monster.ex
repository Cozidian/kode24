defmodule DungeonGame.Monster do
  @moduledoc """
  Monster definitions and round-based scaling.

  Monsters advance through four tiers every three rounds:
    Rounds  1–3  → Goblin
    Rounds  4–6  → Orc
    Rounds  7–9  → Troll
    Rounds 10+   → Dragon

  Within each tier, base HP grows by 5 per round to keep pressure increasing.

  Each monster type has a set of `actions` it may use during its turn. Actions
  are chosen randomly by weight each round; see `DungeonGame.Combat` for how
  each action type is resolved.

  Action types:
    - `:attack`       — standard melee attack using the monster's `damage` field
    - `:heavy_attack` — powerful swing with a hit penalty; uses `damage` and `hit_penalty`
    - `:ranged`       — auto-hits (bypasses AC); uses `damage`
    - `:heal`         — monster regenerates HP; uses `amount`
    - `:steal_potion` — steals a potion from the player (no direct damage)
  """

  defstruct [:name, :hp, :max_hp, :damage, :armor_class, :actions]

  @types [
    %{
      name: "Goblin",
      base_hp: 12,
      damage: "1d6",
      armor_class: 9,
      actions: [
        %{name: "Scratch",     type: :attack,       weight: 3},
        %{name: "Throw Rock",  type: :ranged,       damage: "1d4", weight: 1},
        %{name: "Pick Pocket", type: :steal_potion,              weight: 1}
      ]
    },
    %{
      name: "Orc",
      base_hp: 25,
      damage: "1d8",
      armor_class: 11,
      actions: [
        %{name: "Cleave",        type: :attack,       weight: 3},
        %{name: "Power Smash",   type: :heavy_attack, damage: "2d8", hit_penalty: 4, weight: 1},
        %{name: "Brutish Shove", type: :ranged,       damage: "1d4", weight: 1}
      ]
    },
    %{
      name: "Troll",
      base_hp: 45,
      damage: "2d6",
      armor_class: 13,
      actions: [
        %{name: "Slam",          type: :attack, weight: 3},
        %{name: "Regenerate",    type: :heal,   amount: "1d8", weight: 1},
        %{name: "Boulder Throw", type: :ranged, damage: "1d10", weight: 1}
      ]
    },
    %{
      name: "Dragon",
      base_hp: 70,
      damage: "2d8",
      armor_class: 15,
      actions: [
        %{name: "Claw Strike", type: :attack,       weight: 3},
        %{name: "Fire Breath", type: :ranged,       damage: "1d10", weight: 2},
        %{name: "Tail Swipe",  type: :heavy_attack, damage: "3d6", hit_penalty: 3, weight: 1}
      ]
    }
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
      armor_class: type.armor_class,
      actions: type.actions
    }
  end
end
