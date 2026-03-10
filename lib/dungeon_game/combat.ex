defmodule DungeonGame.Combat do
  @moduledoc """
  Turn-based combat resolution.

  ## Turn structure

  Each full turn is two phases:

  1. **Action phase** — `act/4` resolves the player's main action and returns
     `{:monster_dead | :alive, player, monster, log_entries}`.  No monster
     counter-attack occurs yet.

  2. **Bonus-action phase** — `bonus/4` resolves the player's bonus action and
     then the monster's counter-attack, returning
     `{:continue | :player_dead, player, monster, log_entries}`.

  ### Player actions (main)
  - `:attack` — player attacks the monster
  - `:defend` — player braces (+5 AC for the incoming monster attack); sets
    `player.defending = true` which `bonus/4` reads
  - `:skip`   — player does nothing

  ### Player bonus actions
  - `:heal` — player drinks a potion (2d4 HP); no potions → wasted bonus action
  - `:skip` — player does nothing

  The monster always counter-attacks at the end of the bonus phase.

  ## Legacy shim

  `tick/4` remains for backward compatibility:
  - `tick(p, m, :attack, r)` → `act(:attack)` then `bonus(:skip)`
  - `tick(p, m, :defend, r)` → `act(:defend)` then `bonus(:skip)`
  - `tick(p, m, :heal,   r)` → `act(:skip)`   then `bonus(:heal)`

  The `roller` argument (`fn sides -> integer()`) is injected for determinism in tests.
  """

  alias DungeonGame.{Dice, Loot, Monster, Player}

  @type roller :: Dice.roller()
  @type combatant :: %{
          required(:hp) => integer(),
          required(:armor_class) => integer(),
          required(:damage) => String.t(),
          required(:name) => String.t()
        }
  @type action :: :attack | :defend | :skip
  @type bonus_action :: :heal | :skip

  # ---------------------------------------------------------------------------
  # Public API — act/4
  # ---------------------------------------------------------------------------

  @doc """
  Resolves the player's main action. The monster does NOT counter-attack yet.

  Returns:
  - `{:monster_dead, player, monster, log}` — monster was slain
  - `{:alive, player, monster, log}` — both survive; proceed to `bonus/4`
  """
  @spec act(combatant(), combatant(), action(), roller()) ::
          {:monster_dead | :alive, combatant(), combatant(), [String.t()]}
  def act(player, monster, action \\ :attack, roller \\ &:rand.uniform/1)

  def act(player, monster, :attack, roller) do
    {log1, monster, hit1?} = do_player_attack(player, monster, roller)

    player =
      if has_upgrade?(player, :lifesteal) and hit1?,
        do: %{player | hp: min(player.max_hp, player.hp + 2)},
        else: player

    logs = [log1]

    {logs, monster, player} =
      if has_upgrade?(player, :double_strike) and alive?(monster) do
        {log2, monster, hit2?} = do_player_attack(player, monster, roller)

        player =
          if has_upgrade?(player, :lifesteal) and hit2?,
            do: %{player | hp: min(player.max_hp, player.hp + 2)},
            else: player

        {logs ++ [log2], monster, player}
      else
        {logs, monster, player}
      end

    if not alive?(monster) do
      player = %{player | xp: player.xp + monster.xp}
      {player, level_up_log} = apply_level_up(player, roller)
      {player, loot_log} = apply_loot(player, monster, roller)

      {:monster_dead, player, monster,
       logs ++ ["The #{monster.name} is defeated!"] ++ level_up_log ++ loot_log}
    else
      {:alive, player, monster, logs}
    end
  end

  def act(player, monster, :defend, _roller) do
    player = %{player | defending: true}
    {:alive, player, monster, ["You brace yourself. (+5 AC this round)"]}
  end

  def act(player, monster, :skip, _roller) do
    {:alive, player, monster, ["You skip your action."]}
  end

  # ---------------------------------------------------------------------------
  # Public API — bonus/4
  # ---------------------------------------------------------------------------

  @doc """
  Resolves the player's bonus action, then the monster counter-attacks.

  If `player.defending` is `true` (set by `act(:defend)`), the monster's attack
  is made against an effective AC 5 higher than normal. The flag is cleared
  after the monster acts.

  Returns:
  - `{:continue, player, monster, log}` — both combatants survive
  - `{:player_dead, player, monster, log}` — player was slain by the counter-attack
  """
  @spec bonus(combatant(), combatant(), bonus_action(), roller()) ::
          {:continue | :player_dead, combatant(), combatant(), [String.t()]}
  def bonus(player, monster, bonus_action \\ :skip, roller \\ &:rand.uniform/1)

  def bonus(player, monster, :heal, roller) do
    {heal_log, player} =
      if player.potions > 0 do
        dice = if has_upgrade?(player, :empower), do: "4d4", else: "2d4"
        amount = Dice.roll(dice, roller)

        new_potions =
          if has_upgrade?(player, :triage), do: player.potions, else: player.potions - 1

        p = %{player | hp: min(player.max_hp, player.hp + amount), potions: new_potions}
        {"You drink a potion and recover #{amount} HP!", p}
      else
        {"You reach for a potion — none left!", player}
      end

    {monster_logs, player, monster} = monster_act_with_defend(monster, player, roller)

    if not alive?(player) do
      {:player_dead, player, monster, [heal_log] ++ monster_logs ++ ["You have been defeated!"]}
    else
      {:continue, player, monster, [heal_log] ++ monster_logs}
    end
  end

  def bonus(player, monster, :skip, roller) do
    {monster_logs, player, monster} = monster_act_with_defend(monster, player, roller)

    if not alive?(player) do
      {:player_dead, player, monster, monster_logs ++ ["You have been defeated!"]}
    else
      {:continue, player, monster, monster_logs}
    end
  end

  # ---------------------------------------------------------------------------
  # Legacy shim — tick/4
  # ---------------------------------------------------------------------------

  @doc """
  Single-call combat exchange (legacy). Delegates to `act/4` + `bonus/4`.

  - `tick(p, m, :attack, r)` → `act(:attack)` then `bonus(:skip)`
  - `tick(p, m, :defend, r)` → `act(:defend)` then `bonus(:skip)`
  - `tick(p, m, :heal,   r)` → `act(:skip)`   then `bonus(:heal)`
  """
  @spec tick(combatant(), combatant(), :attack | :defend | :heal, roller()) ::
          {:continue | :monster_dead | :player_dead, combatant(), combatant(), [String.t()]}
  def tick(player, monster, action \\ :attack, roller \\ &:rand.uniform/1)

  def tick(player, monster, :attack, roller) do
    case act(player, monster, :attack, roller) do
      {:monster_dead, player, monster, log} ->
        {:monster_dead, player, monster, log}

      {:alive, player, monster, action_log} ->
        combine_with_bonus(player, monster, :skip, roller, action_log)
    end
  end

  def tick(player, monster, :defend, roller) do
    {:alive, player, monster, action_log} = act(player, monster, :defend, roller)
    combine_with_bonus(player, monster, :skip, roller, action_log)
  end

  def tick(player, monster, :heal, roller) do
    {:alive, player, monster, _} = act(player, monster, :skip, roller)
    combine_with_bonus(player, monster, :heal, roller, [])
  end

  defp combine_with_bonus(player, monster, bonus_action, roller, prefix_log) do
    case bonus(player, monster, bonus_action, roller) do
      {:continue, player, monster, bonus_log} ->
        {:continue, player, monster, prefix_log ++ bonus_log}

      {:player_dead, player, monster, bonus_log} ->
        {:player_dead, player, monster, prefix_log ++ bonus_log}
    end
  end

  # ---------------------------------------------------------------------------
  # Combat primitives (public)
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Monster action system
  # ---------------------------------------------------------------------------

  # Applies +5 AC if the player is defending, then runs monster_act.
  # Also applies Fortify (+5 HP) and Thorns (2 dmg reflected) if equipped.
  # Resets defending flag and restores original armor_class afterward.
  defp monster_act_with_defend(monster, player, roller) do
    {effective_player, original_ac} =
      if player.defending do
        p = %{player | armor_class: player.armor_class + 5, defending: false}

        p =
          if has_upgrade?(player, :fortify), do: %{p | hp: min(player.max_hp, p.hp + 5)}, else: p

        {p, player.armor_class}
      else
        {player, player.armor_class}
      end

    {logs, damaged, monster} = monster_act(monster, effective_player, roller)

    {monster, extra_logs} =
      if player.defending and has_upgrade?(player, :thorns) do
        {apply_damage(monster, 2), ["Your thorns deal 2 damage to the #{monster.name}!"]}
      else
        {monster, []}
      end

    result_player = %{damaged | armor_class: original_ac, defending: false}
    {logs ++ extra_logs, result_player, monster}
  end

  # Uses the monster's pre-selected next_action (or picks randomly as fallback).
  defp monster_act(monster, player, roller) do
    action = monster.next_action || Monster.pick_action(monster.actions)
    execute_action(action, monster, player, roller)
  end

  defp execute_action(%{type: :attack}, monster, player, roller) do
    {log, player} = resolve_attack(monster, player, "The #{monster.name}", "you", roller)
    {[log], player, monster}
  end

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

  defp execute_action(%{type: :ranged} = action, monster, player, roller) do
    damage = Dice.roll(action.damage, roller)
    player = apply_damage(player, damage)
    log = "The #{monster.name}'s #{action.name} hits you for #{damage} damage!"
    {[log], player, monster}
  end

  defp execute_action(%{type: :heal} = action, monster, player, roller) do
    amount = Dice.roll(action.amount, roller)
    monster = %{monster | hp: min(monster.max_hp, monster.hp + amount)}
    log = "The #{monster.name} uses #{action.name} and recovers #{amount} HP!"
    {[log], player, monster}
  end

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

  defp apply_level_up(player, roller) do
    leveled = Player.apply_level_up(player, roller)

    if leveled.level > player.level do
      {leveled,
       ["You reached level #{leveled.level}! +#{leveled.max_hp - player.max_hp} max HP!"]}
    else
      {leveled, []}
    end
  end

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

  # Performs a player attack, applying Execute (+3 dmg at ≤30% HP) and returning
  # whether the attack landed (used by Lifesteal).
  defp do_player_attack(player, monster, roller) do
    effective_player =
      if has_upgrade?(player, :execute) and monster.hp <= ceil(monster.max_hp * 0.3) do
        %{player | bonus_damage: player.bonus_damage + 3}
      else
        player
      end

    old_hp = monster.hp
    {log, monster} = resolve_attack(effective_player, monster, "You", monster.name, roller)
    {log, monster, monster.hp < old_hp}
  end

  defp has_upgrade?(combatant, id) do
    action_match =
      [:upgrade_attack, :upgrade_defend, :upgrade_heal]
      |> Enum.any?(fn slot ->
        u = Map.get(combatant, slot)
        u != nil and u.id == id
      end)

    passive_match =
      combatant
      |> Map.get(:upgrades_passive, [])
      |> Enum.any?(&(&1.id == id))

    action_match or passive_match
  end

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
