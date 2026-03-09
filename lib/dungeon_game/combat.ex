defmodule DungeonGame.Combat do
  @moduledoc """
  Turn-based combat resolution.

  The player acts first each round. All functions accept an optional `roller`
  (see `DungeonGame.Dice`) so tests can force deterministic outcomes.
  """

  alias DungeonGame.Dice

  @type roller :: Dice.roller()
  @type combatant :: %{
          required(:hp) => integer(),
          required(:armor_class) => integer(),
          required(:damage) => String.t(),
          required(:name) => String.t()
        }
  @type action :: :attack | :defend | :heal

  @doc """
  Resolves a single attack from `attacker` against `defender`.

  Rolls 1d20; if the result meets or beats `defender.armor_class` it is a hit.
  Returns `{:hit, damage}` or `:miss`.
  """
  @spec attack(combatant(), combatant(), roller()) :: {:hit, pos_integer()} | :miss
  def attack(attacker, defender, roller \\ &:rand.uniform/1) do
    roll = roller.(20)

    if roll >= defender.armor_class do
      damage = Dice.roll(attacker.damage, roller)
      {:hit, damage}
    else
      :miss
    end
  end

  @doc "Subtracts `damage` from a combatant's HP, clamped to zero."
  @spec apply_damage(combatant(), non_neg_integer()) :: combatant()
  def apply_damage(combatant, damage) do
    %{combatant | hp: max(0, combatant.hp - damage)}
  end

  @doc "Returns `true` if the combatant has HP remaining."
  @spec alive?(combatant()) :: boolean()
  def alive?(combatant), do: combatant.hp > 0

  @doc """
  Processes one full combat exchange given a player `action`.

  Actions:
  - `:attack` — player attacks the monster, then monster counter-attacks if alive.
  - `:defend` — player skips their attack and braces (+5 AC this round); monster attacks.
  - `:heal`   — player drinks a potion (restores 2d4 HP, decrements `player.potions`);
                 monster still counter-attacks. If no potions remain the turn is wasted.

  Returns one of:
  - `{:continue, player, monster, log_entries}` — both survive the exchange
  - `{:monster_dead, player, monster, log_entries}` — monster was slain (`:attack` only)
  - `{:player_dead, player, monster, log_entries}` — player was slain
  """
  @spec tick(combatant(), combatant(), action(), roller()) ::
          {:continue | :monster_dead | :player_dead, combatant(), combatant(), [String.t()]}
  def tick(player, monster, action \\ :attack, roller \\ &:rand.uniform/1)

  def tick(player, monster, :attack, roller) do
    {player_log, monster} = resolve_attack(player, monster, "You", monster.name, roller)

    if not alive?(monster) do
      {:monster_dead, player, monster, [player_log, "The #{monster.name} is defeated!"]}
    else
      {monster_log, player} = resolve_attack(monster, player, "The #{monster.name}", "you", roller)

      if not alive?(player) do
        {:player_dead, player, monster, [player_log, monster_log, "You have been defeated!"]}
      else
        {:continue, player, monster, [player_log, monster_log]}
      end
    end
  end

  def tick(player, monster, :defend, roller) do
    player_log = "You brace yourself. (+5 AC this round)"
    fortified = %{player | armor_class: player.armor_class + 5}

    {monster_log, damaged} =
      resolve_attack(monster, fortified, "The #{monster.name}", "you", roller)

    result_player = %{damaged | armor_class: player.armor_class}

    if not alive?(result_player) do
      {:player_dead, result_player, monster, [player_log, monster_log, "You have been defeated!"]}
    else
      {:continue, result_player, monster, [player_log, monster_log]}
    end
  end

  def tick(player, monster, :heal, roller) do
    {player_log, healed} =
      if player.potions > 0 do
        amount = Dice.roll("2d4", roller)
        p = %{player | hp: min(player.max_hp, player.hp + amount), potions: player.potions - 1}
        {"You drink a potion and recover #{amount} HP!", p}
      else
        {"You reach for a potion — none left!", player}
      end

    {monster_log, damaged} =
      resolve_attack(monster, healed, "The #{monster.name}", "you", roller)

    if not alive?(damaged) do
      {:player_dead, damaged, monster, [player_log, monster_log, "You have been defeated!"]}
    else
      {:continue, damaged, monster, [player_log, monster_log]}
    end
  end

  # Resolves a single attack and returns {log_entry, updated_defender}.
  defp resolve_attack(attacker, defender, attacker_label, defender_label, roller) do
    case attack(attacker, defender, roller) do
      {:hit, damage} ->
        defender = apply_damage(defender, damage)
        log = "#{attacker_label} hit #{defender_label} for #{damage} damage."
        {log, defender}

      :miss ->
        log = "#{attacker_label} missed #{defender_label}."
        {log, defender}
    end
  end
end
