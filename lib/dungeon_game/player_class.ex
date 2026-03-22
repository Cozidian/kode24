defmodule DungeonGame.PlayerClass do
  @moduledoc """
  Defines the three playable classes and creates starting `%Player{}` structs.

  - **Warrior** — high HP and AC, builds Shield Charges with Defend
  - **Rogue** — fast and evasive, builds Combo on hits for a Finisher
  - **Mage** — glass cannon, spends Mana on powerful spells
  """

  alias DungeonGame.Player

  defstruct [:id, :name, :description, :icon, :hp, :armor_class, :damage, :hit_die, :max_mana]

  @doc "Returns the list of all available player classes."
  def all do
    [
      %__MODULE__{
        id: :warrior,
        name: "Warrior",
        description:
          "Defend to build Shield Charges (max 3). Each charge absorbs one incoming hit.",
        icon: "⚔️",
        hp: 12,
        armor_class: 16,
        damage: "1d8",
        hit_die: "1d10",
        max_mana: 0
      },
      %__MODULE__{
        id: :rogue,
        name: "Rogue",
        description: "Each hit builds Combo. At 3+ Combo, unleash a Finisher for massive damage.",
        icon: "🗡️",
        hp: 8,
        armor_class: 13,
        damage: "1d6",
        hit_die: "1d6",
        max_mana: 0
      },
      %__MODULE__{
        id: :mage,
        name: "Mage",
        description:
          "Spend Mana on Fireball (2✨, ignores AC) or Frost Nova (1✨, halves next hit).",
        icon: "🔮",
        hp: 6,
        armor_class: 11,
        damage: "1d4",
        hit_die: "1d4",
        max_mana: 3
      }
    ]
  end

  @doc """
  Creates a fresh `%Player{}` with stats set for `class_id` and the given `name`.
  """
  def new_player(class_id, name) do
    class = Enum.find(all(), &(&1.id == class_id))

    %Player{
      name: name,
      class: class_id,
      hp: class.hp,
      max_hp: class.hp,
      armor_class: class.armor_class,
      damage: class.damage,
      potions: 0,
      mana: class.max_mana,
      max_mana: class.max_mana
    }
  end
end
