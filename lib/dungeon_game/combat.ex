defmodule DungeonGame.Combat do
  @moduledoc """
  Turn-based combat resolution.

  The player acts first each round. All functions accept an optional `roller`
  (see `DungeonGame.Dice`) so tests can force deterministic outcomes.

  Monster counter-attacks are resolved via `monster_act/3`, which randomly picks
  one of the monster's available actions (weighted by `action.weight`). Action
  selection is non-deterministic and uses `:rand.uniform/1` directly so that
  the injectable `roller` remains reserved for hit/damage rolls.
  """

  alias DungeonGame.{Dice, Loot, Monster, Player}

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
    effective_ac = defender.armor_class + Map.get(defender, :bonus_ac, 0)

    if roll >= effective_ac do
      damage = Dice.roll(attacker.damage, roller) + Map.get(attacker, :bonus_damage, 0)
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

  The monster's counter-attack is selected randomly from its `actions` list.

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
      player = %{player | xp: player.xp + monster.xp}
      {player, level_up_log} = apply_level_up(player, roller)
      {player, loot_log} = apply_loot(player, monster, roller)

      {:monster_dead, player, monster,
       [player_log, "The #{monster.name} is defeated!"] ++ level_up_log ++ loot_log}
    else
      {monster_logs, player, monster} = monster_act(monster, player, roller)

      if not alive?(player) do
        {:player_dead, player, monster,
         [player_log] ++ monster_logs ++ ["You have been defeated!"]}
      else
        {:continue, player, monster, [player_log] ++ monster_logs}
      end
    end
  end

  def tick(player, monster, :defend, roller) do
    player_log = "You brace yourself. (+5 AC this round)"
    fortified = %{player | armor_class: player.armor_class + 5}

    {monster_logs, damaged, monster} = monster_act(monster, fortified, roller)

    result_player = %{damaged | armor_class: player.armor_class}

    if not alive?(result_player) do
      {:player_dead, result_player, monster,
       [player_log] ++ monster_logs ++ ["You have been defeated!"]}
    else
      {:continue, result_player, monster, [player_log] ++ monster_logs}
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

    {monster_logs, damaged, monster} = monster_act(monster, healed, roller)

    if not alive?(damaged) do
      {:player_dead, damaged, monster,
       [player_log] ++ monster_logs ++ ["You have been defeated!"]}
    else
      {:continue, damaged, monster, [player_log] ++ monster_logs}
    end
  end

  # ---------------------------------------------------------------------------
  # Monster action system
  # ---------------------------------------------------------------------------

  # Uses the monster's pre-selected next_action (or picks randomly as fallback).
  # Returns {log_entries, updated_player, updated_monster}.
  defp monster_act(monster, player, roller) do
    action = monster.next_action || Monster.pick_action(monster.actions)
    execute_action(action, monster, player, roller)
  end

  # Standard melee attack — uses the monster's own damage dice.
  defp execute_action(%{type: :attack}, monster, player, roller) do
    {log, player} = resolve_attack(monster, player, "The #{monster.name}", "you", roller)
    {[log], player, monster}
  end

  # Heavy attack — powerful but harder to land (hit_penalty reduces the roll).
  defp execute_action(%{type: :heavy_attack} = action, monster, player, roller) do
    roll = roller.(20)
    penalty = Map.get(action, :hit_penalty, 0)

    effective_ac = player.armor_class + Map.get(player, :bonus_ac, 0)

    if roll - penalty >= effective_ac do
      damage = Dice.roll(action.damage, roller)
      player = apply_damage(player, damage)
      log = "The #{monster.name}'s #{action.name} connects for #{damage} damage!"
      {[log], player, monster}
    else
      log = "The #{monster.name}'s #{action.name} misses wildly!"
      {[log], player, monster}
    end
  end

  # Ranged / elemental attack — always hits, bypasses armor class.
  defp execute_action(%{type: :ranged} = action, monster, player, roller) do
    damage = Dice.roll(action.damage, roller)
    player = apply_damage(player, damage)
    log = "The #{monster.name}'s #{action.name} hits you for #{damage} damage!"
    {[log], player, monster}
  end

  # Regeneration — monster heals itself this turn instead of attacking.
  defp execute_action(%{type: :heal} = action, monster, player, roller) do
    amount = Dice.roll(action.amount, roller)
    monster = %{monster | hp: min(monster.max_hp, monster.hp + amount)}
    log = "The #{monster.name} uses #{action.name} and recovers #{amount} HP!"
    {[log], player, monster}
  end

  # Pick pocket — steals a potion; falls back to a scratch if the player has none.
  defp execute_action(%{type: :steal_potion}, monster, player, roller) do
    if player.potions > 0 do
      player = %{player | potions: player.potions - 1}
      log = "The #{monster.name} picks your pocket and steals a potion!"
      {[log], player, monster}
    else
      {log, player} = resolve_attack(monster, player, "The #{monster.name}", "you", roller)
      {[log], player, monster}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Checks for a level-up after XP is awarded.
  # Returns {updated_player, log_entries} — log is empty when no level-up occurred.
  defp apply_level_up(player, roller) do
    leveled = Player.apply_level_up(player, roller)

    if leveled.level > player.level do
      {leveled,
       ["You reached level #{leveled.level}! +#{leveled.max_hp - player.max_hp} max HP!"]}
    else
      {leveled, []}
    end
  end

  # Rolls for all loot drops and applies each to the player.
  # Returns {updated_player, log_entries}.
  defp apply_loot(player, monster, roller) do
    {player, logs} =
      Enum.reduce(Loot.roll(monster, roller), {player, []}, fn
        {:gold, amount}, {p, logs} ->
          {%{p | gold: p.gold + amount}, ["You found #{amount} gold!" | logs]}

        {:item, item}, {p, logs} ->
          {%{p | inventory: [item | p.inventory]}, ["You found a #{item.name}!" | logs]}

        {:potion, amount}, {p, logs} ->
          {%{p | potions: p.potions + amount}, ["You found a potion!" | logs]}
      end)

    {player, Enum.reverse(logs)}
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
