defmodule DungeonGame.Upgrade do
  @moduledoc """
  Player upgrades chosen on level-up.

  Each upgrade has a `type` that determines which slot it occupies:
  - `:attack`  — replaces the current attack upgrade (only one active at a time)
  - `:defend`  — replaces the current defend upgrade
  - `:heal`    — replaces the current heal upgrade
  - `:passive` — appended to `upgrades_passive` (unlimited, stackable)

  Some passive upgrades immediately modify player stats when applied:
  - `:tough`   — +3 max HP and current HP
  - `:armored` — +1 armor class (bonus_ac)
  """

  defstruct [:id, :type, :name, :description]

  @doc "Returns the full upgrade catalog."
  @spec all() :: [%__MODULE__{}]
  def all, do: catalog()

  @doc """
  Returns up to `n` random upgrade choices for the player.

  Currently-equipped action upgrades (attack/defend/heal slots) are excluded
  so the player can't pick what they already have. Passives are always eligible.
  """
  @spec random_choices(%DungeonGame.Player{}, pos_integer()) :: [%__MODULE__{}]
  def random_choices(player, n) do
    equipped_ids =
      [player.upgrade_attack, player.upgrade_defend, player.upgrade_heal]
      |> Enum.filter(& &1)
      |> Enum.map(& &1.id)

    catalog()
    |> Enum.reject(&(&1.id in equipped_ids))
    |> Enum.shuffle()
    |> Enum.take(n)
  end

  @doc """
  Applies an upgrade to the player.

  - Action upgrades (attack/defend/heal) replace the current slot.
  - Passive upgrades are appended to `upgrades_passive`.
  - `:tough` immediately adds +3 to both `max_hp` and `hp`.
  - `:armored` immediately adds +1 to `bonus_ac`.
  """
  @spec apply(%DungeonGame.Player{}, %__MODULE__{}) :: %DungeonGame.Player{}
  def apply(player, %__MODULE__{type: :attack} = upgrade) do
    %{player | upgrade_attack: upgrade}
  end

  def apply(player, %__MODULE__{type: :defend} = upgrade) do
    %{player | upgrade_defend: upgrade}
  end

  def apply(player, %__MODULE__{type: :heal} = upgrade) do
    %{player | upgrade_heal: upgrade}
  end

  def apply(player, %__MODULE__{type: :passive, id: :tough} = upgrade) do
    player = %{player | upgrades_passive: [upgrade | player.upgrades_passive]}
    %{player | max_hp: player.max_hp + 3, hp: player.hp + 3}
  end

  def apply(player, %__MODULE__{type: :passive, id: :armored} = upgrade) do
    player = %{player | upgrades_passive: [upgrade | player.upgrades_passive]}
    %{player | bonus_ac: player.bonus_ac + 1}
  end

  def apply(player, %__MODULE__{type: :passive} = upgrade) do
    %{player | upgrades_passive: [upgrade | player.upgrades_passive]}
  end

  # ---------------------------------------------------------------------------
  # Catalog
  # ---------------------------------------------------------------------------

  defp catalog do
    [
      # Attack upgrades
      %__MODULE__{
        id: :double_strike,
        type: :attack,
        name: "Double Strike",
        description: "Attack twice each turn."
      },
      %__MODULE__{
        id: :lifesteal,
        type: :attack,
        name: "Lifesteal",
        description: "Heal 2 HP each time you land a hit."
      },
      %__MODULE__{
        id: :execute,
        type: :attack,
        name: "Execute",
        description: "Deal +3 bonus damage to monsters below 30% HP."
      },
      # Defend upgrades
      %__MODULE__{
        id: :thorns,
        type: :defend,
        name: "Thorns",
        description: "Reflect 2 damage to any attacker when you defend."
      },
      %__MODULE__{
        id: :fortify,
        type: :defend,
        name: "Fortify",
        description: "Recover 5 HP when you choose to defend."
      },
      %__MODULE__{
        id: :counter,
        type: :defend,
        name: "Counter",
        description: "Auto-attack the monster if it misses you while defending."
      },
      # Heal upgrades
      %__MODULE__{
        id: :empower,
        type: :heal,
        name: "Empower",
        description: "Potions heal 4d4 instead of 2d4."
      },
      %__MODULE__{
        id: :triage,
        type: :heal,
        name: "Triage",
        description: "Using a potion does not consume it."
      },
      # Passive upgrades
      %__MODULE__{
        id: :tough,
        type: :passive,
        name: "Tough",
        description: "+3 maximum HP."
      },
      %__MODULE__{
        id: :armored,
        type: :passive,
        name: "Armored",
        description: "+1 armor class."
      },
      %__MODULE__{
        id: :lucky,
        type: :passive,
        name: "Lucky",
        description: "Re-roll one miss per turn."
      }
    ]
  end
end
