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

  defstruct [:name, :hp, :max_hp, :damage, :armor_class, :actions, :next_action, gold: 5]

  @types [
    %{
      name: "Goblin",
      base_hp: 6,
      damage: "1d4",
      armor_class: 9,
      gold: 5,
      actions: [
        %{name: "Scratch", type: :attack, weight: 3},
        %{name: "Throw Rock", type: :ranged, damage: "1d4", weight: 1},
        %{name: "Pick Pocket", type: :steal_potion, weight: 1}
      ]
    },
    %{
      name: "Orc",
      base_hp: 25,
      damage: "1d8",
      armor_class: 11,
      gold: 5,
      actions: [
        %{name: "Cleave", type: :attack, weight: 3},
        %{name: "Power Smash", type: :heavy_attack, damage: "2d8", hit_penalty: 4, weight: 1},
        %{name: "Brutish Shove", type: :ranged, damage: "1d4", weight: 1}
      ]
    },
    %{
      name: "Troll",
      base_hp: 45,
      damage: "2d6",
      armor_class: 13,
      gold: 5,
      actions: [
        %{name: "Slam", type: :attack, weight: 3},
        %{name: "Regenerate", type: :heal, amount: "1d8", weight: 1},
        %{name: "Boulder Throw", type: :ranged, damage: "1d10", weight: 1}
      ]
    },
    %{
      name: "Dragon",
      base_hp: 70,
      damage: "2d8",
      armor_class: 15,
      gold: 5,
      actions: [
        %{name: "Claw Strike", type: :attack, weight: 3},
        %{name: "Fire Breath", type: :ranged, damage: "1d10", weight: 2},
        %{name: "Tail Swipe", type: :heavy_attack, damage: "3d6", hit_penalty: 3, weight: 1}
      ]
    }
  ]

  @doc """
  Spawns a monster scaled to the given `round` number.
  The monster's first intended action is pre-selected and stored in `next_action`.
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
      actions: type.actions,
      next_action: pick_action(type.actions),
      gold: type.gold
    }
  end

  @doc """
  Spawns an elite monster scaled to the given `round` number.
  Same tier as `for_round/1` but with 50% more HP, +2 AC, and double gold.
  """
  @spec elite_for_round(pos_integer()) :: %__MODULE__{}
  def elite_for_round(round) do
    base = for_round(round)
    elite_hp = trunc(base.hp * 1.5)

    %{
      base
      | hp: elite_hp,
        max_hp: elite_hp,
        armor_class: base.armor_class + 2,
        gold: base.gold * 2
    }
  end

  @doc """
  Randomly picks one action from `actions` using weighted selection.
  Used externally to refresh a monster's `next_action` after each turn.
  """
  @spec pick_action([map()]) :: map()
  def pick_action(actions) do
    total = Enum.sum(Enum.map(actions, & &1.weight))
    roll = :rand.uniform(total)

    Enum.reduce_while(actions, roll, fn action, remaining ->
      if remaining <= action.weight do
        {:halt, action}
      else
        {:cont, remaining - action.weight}
      end
    end)
  end
end
