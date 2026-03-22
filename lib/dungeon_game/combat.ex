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
  - `:attack`    — player attacks the monster
  - `:defend`    — player braces (+5 AC this round); Warrior gains a shield charge
  - `:skip`      — player does nothing
  - `:finisher`  — Rogue only: deal combo × 1d6 damage, reset combo
  - `:fireball`  — Mage only: 2 mana, 2d8 ignoring AC
  - `:frost_nova` — Mage only: 1 mana, 1d6 + halves next incoming hit

  ### Player bonus actions
  - `:heal` — player drinks a potion (2d4 HP); no potions → wasted bonus action
  - `:skip` — player does nothing

  ### Class mechanics (applied automatically during act/bonus)
  - **Warrior** `shield_charges`: Defend adds 1 charge (max 3); each charge absorbs
    one incoming damage hit.
  - **Rogue** `combo`: Hits increment; misses/defend reset to 0. Finisher consumes all.
  - **Mage** `mana`: Regenerates 1 per turn (at start of `act/4`); spells spend mana.
    `frost_nova_active` flag halves the next incoming hit, then clears.

  ## Legacy shim

  `tick/4` remains for backward compatibility:
  - `tick(p, m, :attack,    r)` → `act(:attack)` then `bonus(:skip)`
  - `tick(p, m, :defend,    r)` → `act(:defend)` then `bonus(:skip)`
  - `tick(p, m, :heal,      r)` → `act(:skip)`   then `bonus(:heal)`
  - `tick(p, m, :finisher,  r)` → `act(:finisher)` then `bonus(:skip)`
  - `tick(p, m, :fireball,  r)` → `act(:fireball)` then `bonus(:skip)`
  - `tick(p, m, :frost_nova,r)` → `act(:frost_nova)` then `bonus(:skip)`

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
  @type action :: :attack | :defend | :skip | :finisher | :fireball | :frost_nova
  @type bonus_action :: :heal | :skip

  # ---------------------------------------------------------------------------
  # Public API — act/4
  # ---------------------------------------------------------------------------

  @doc """
  Resolves the player's main action. The monster does NOT counter-attack yet.
  Mage mana regenerates by 1 at the start of this phase (capped at max_mana).

  Returns:
  - `{:monster_dead, player, monster, log}` — monster was slain
  - `{:alive, player, monster, log}` — both survive; proceed to `bonus/4`
  """
  @spec act(combatant(), combatant(), action(), roller()) ::
          {:monster_dead | :alive, combatant(), combatant(), [String.t()]}
  def act(player, monster, action \\ :attack, roller \\ &:rand.uniform/1)

  def act(player, monster, :attack, roller) do
    player = maybe_regen_mana(player)
    {log1, monster, hit1?} = do_player_attack(player, monster, roller)

    player =
      if has_upgrade?(player, :lifesteal) and hit1?,
        do: %{player | hp: min(player.max_hp, player.hp + 2)},
        else: player

    logs = [log1]

    {logs, monster, player, any_hit?} =
      if has_upgrade?(player, :double_strike) and alive?(monster) do
        {log2, monster, hit2?} = do_player_attack(player, monster, roller)

        player =
          if has_upgrade?(player, :lifesteal) and hit2?,
            do: %{player | hp: min(player.max_hp, player.hp + 2)},
            else: player

        {logs ++ [log2], monster, player, hit1? or hit2?}
      else
        {logs, monster, player, hit1?}
      end

    player = update_combo(player, any_hit?)

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
    player = maybe_regen_mana(player)
    player = %{player | defending: true}

    {player, extra_log} =
      cond do
        player.class == :warrior ->
          charges = min(3, player.shield_charges + 1)
          {%{player | shield_charges: charges}, ["🛡 Shield raised! (#{charges}/3 charges)"]}

        player.class == :rogue ->
          {%{player | combo: 0}, if(player.combo > 0, do: ["Combo broken!"], else: [])}

        true ->
          {player, []}
      end

    {:alive, player, monster, ["You brace yourself. (+5 AC this round)"] ++ extra_log}
  end

  def act(player, monster, :skip, _roller) do
    player = maybe_regen_mana(player)
    {:alive, player, monster, ["You skip your action."]}
  end

  def act(player, monster, :finisher, roller) do
    player = maybe_regen_mana(player)
    combo = player.combo
    player = %{player | combo: 0}

    if combo > 0 do
      damage = combo * Dice.roll("1d6", roller)
      monster = apply_damage(monster, damage)
      log = "💥 Finisher! #{combo} × 1d6 = #{damage} damage!"

      if not alive?(monster) do
        player = %{player | xp: player.xp + monster.xp}
        {player, level_up_log} = apply_level_up(player, roller)
        {player, loot_log} = apply_loot(player, monster, roller)

        {:monster_dead, player, monster,
         [log, "The #{monster.name} is defeated!"] ++ level_up_log ++ loot_log}
      else
        {:alive, player, monster, [log]}
      end
    else
      {:alive, player, monster, ["No combo to unleash!"]}
    end
  end

  def act(player, monster, :fireball, roller) do
    player = maybe_regen_mana(player)

    if player.mana >= 2 do
      player = %{player | mana: player.mana - 2}
      damage = Dice.roll("2d8", roller)
      monster = apply_damage(monster, damage)
      log = "🔥 Fireball! #{damage} damage, ignoring armor!"

      if not alive?(monster) do
        player = %{player | xp: player.xp + monster.xp}
        {player, level_up_log} = apply_level_up(player, roller)
        {player, loot_log} = apply_loot(player, monster, roller)

        {:monster_dead, player, monster,
         [log, "The #{monster.name} is defeated!"] ++ level_up_log ++ loot_log}
      else
        {:alive, player, monster, [log]}
      end
    else
      {:alive, player, monster, ["Not enough mana for Fireball! (need 2✨)"]}
    end
  end

  def act(player, monster, :frost_nova, roller) do
    player = maybe_regen_mana(player)

    if player.mana >= 1 do
      player = %{player | mana: player.mana - 1, frost_nova_active: true}
      damage = Dice.roll("1d6", roller)
      monster = apply_damage(monster, damage)
      log = "❄️ Frost Nova! #{damage} damage and the enemy is chilled!"

      if not alive?(monster) do
        player = %{player | xp: player.xp + monster.xp, frost_nova_active: false}
        {player, level_up_log} = apply_level_up(player, roller)
        {player, loot_log} = apply_loot(player, monster, roller)

        {:monster_dead, player, monster,
         [log, "The #{monster.name} is defeated!"] ++ level_up_log ++ loot_log}
      else
        {:alive, player, monster, [log]}
      end
    else
      {:alive, player, monster, ["Not enough mana for Frost Nova! (need 1✨)"]}
    end
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

  - `tick(p, m, :attack,     r)` → `act(:attack)` then `bonus(:skip)`
  - `tick(p, m, :defend,     r)` → `act(:defend)` then `bonus(:skip)`
  - `tick(p, m, :heal,       r)` → `act(:skip)` then `bonus(:heal)`
  - `tick(p, m, :finisher,   r)` → `act(:finisher)` then `bonus(:skip)`
  - `tick(p, m, :fireball,   r)` → `act(:fireball)` then `bonus(:skip)`
  - `tick(p, m, :frost_nova, r)` → `act(:frost_nova)` then `bonus(:skip)`
  """
  @spec tick(
          combatant(),
          combatant(),
          :attack | :defend | :heal | :finisher | :fireball | :frost_nova,
          roller()
        ) ::
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

  def tick(player, monster, action, roller)
      when action in [:finisher, :fireball, :frost_nova] do
    case act(player, monster, action, roller) do
      {:monster_dead, player, monster, log} ->
        {:monster_dead, player, monster, log}

      {:alive, player, monster, action_log} ->
        combine_with_bonus(player, monster, :skip, roller, action_log)
    end
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

  # Checks shield charges first (Warrior), then applies defend/frost_nova/thorns effects.
  defp monster_act_with_defend(monster, player, roller) do
    action = monster.next_action || Monster.pick_action(monster.actions)

    if player.shield_charges > 0 and damage_action?(action) and not player.defending do
      remaining = player.shield_charges - 1
      player = %{player | shield_charges: remaining, defending: false}
      log = "🛡 Your shield absorbs the #{monster.name}'s attack! (#{remaining} charges left)"
      {[log], player, monster}
    else
      apply_monster_action(action, monster, player, roller)
    end
  end

  defp apply_monster_action(action, monster, player, roller) do
    {effective_player, original_ac} =
      if player.defending do
        p = %{player | armor_class: player.armor_class + 5, defending: false}

        p =
          if has_upgrade?(player, :fortify), do: %{p | hp: min(player.max_hp, p.hp + 5)}, else: p

        {p, player.armor_class}
      else
        {player, player.armor_class}
      end

    hp_before = effective_player.hp
    {logs, result_player, monster} = execute_action(action, monster, effective_player, roller)

    # Frost Nova halves incoming damage on this hit
    {result_player, frost_logs} =
      if player.frost_nova_active and damage_action?(action) and result_player.hp < hp_before do
        damage_taken = hp_before - result_player.hp
        halved = div(damage_taken, 2)
        p = %{result_player | hp: hp_before - halved}
        {p, ["❄️ Frost slows the attack — only #{halved} damage taken!"]}
      else
        {result_player, []}
      end

    {monster, thorns_logs} =
      if player.defending and has_upgrade?(player, :thorns) do
        {apply_damage(monster, 2), ["Your thorns deal 2 damage to the #{monster.name}!"]}
      else
        {monster, []}
      end

    result_player = %{
      result_player
      | armor_class: original_ac,
        defending: false,
        frost_nova_active: false
    }

    {logs ++ frost_logs ++ thorns_logs, result_player, monster}
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

  # Regenerates 1 mana for Mages at the start of each action phase.
  defp maybe_regen_mana(%{max_mana: max} = player) when max > 0 do
    %{player | mana: min(max, player.mana + 1)}
  end

  defp maybe_regen_mana(player), do: player

  # Updates Rogue's combo counter after an attack.
  defp update_combo(%{class: :rogue} = player, true), do: %{player | combo: player.combo + 1}
  defp update_combo(%{class: :rogue} = player, false), do: %{player | combo: 0}
  defp update_combo(player, _), do: player

  # Returns true if the action type deals direct damage to the player.
  defp damage_action?(%{type: type}) when type in [:attack, :heavy_attack, :ranged], do: true
  defp damage_action?(_), do: false

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
  # whether the attack landed (used by Lifesteal and combo tracking).
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
