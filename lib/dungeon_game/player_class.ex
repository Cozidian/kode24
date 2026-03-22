defmodule DungeonGame.PlayerClass do
  @moduledoc """
  Defines the three playable classes and creates starting `%Player{}` structs.

  - **Warrior** — high HP and AC, builds Shield Charges with Defend
  - **Rogue** — fast and evasive, builds Combo on hits for a Finisher
  - **Mage** — glass cannon, spends Mana on powerful spells
  """

  alias DungeonGame.{Card, Player}

  defstruct [:id, :name, :description, :icon, :hp, :armor_class, :damage, :hit_die]

  @doc "Returns the list of all available player classes."
  def all do
    [
      %__MODULE__{
        id: :warrior,
        name: "Warrior",
        description:
          "A heavily armored fighter. Build block with Shield Up, then unleash Shield Slam.",
        icon: "⚔️",
        hp: 60,
        armor_class: 16,
        damage: "1d8",
        hit_die: "1d10"
      },
      %__MODULE__{
        id: :rogue,
        name: "Rogue",
        description: "A nimble assassin. Overwhelm with cheap cards and devastating finishers.",
        icon: "🗡️",
        hp: 45,
        armor_class: 13,
        damage: "1d6",
        hit_die: "1d6"
      },
      %__MODULE__{
        id: :mage,
        name: "Mage",
        description:
          "A glass cannon. Arcane missiles and fireballs ignore armor — but you're fragile.",
        icon: "🔮",
        hp: 30,
        armor_class: 11,
        damage: "1d4",
        hit_die: "1d4"
      }
    ]
  end

  @doc """
  Creates a fresh `%Player{}` with stats set for `class_id` and the given `name`.
  Deals the starting 5-card hand from the class deck.
  """
  def new_player(class_id, name) do
    class = Enum.find(all(), &(&1.id == class_id))
    full_deck = Card.starting_deck(class_id)
    {hand, deck} = Enum.split(full_deck, 5)

    %Player{
      name: name,
      class: class_id,
      hp: class.hp,
      max_hp: class.hp,
      armor_class: class.armor_class,
      damage: class.damage,
      potions: 0,
      hand: hand,
      deck: deck,
      discard: [],
      energy: 3,
      max_energy: 3,
      block: 0,
      dodge_next: false
    }
  end
end
