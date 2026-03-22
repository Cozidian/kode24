defmodule DungeonGame.Combat do
  @moduledoc """
  Card-based combat resolution.

  ## Turn structure

  Each turn is two phases:

  1. **Player phase** — call `play_card/4` for each card the player plays.
     Returns `{:monster_dead | :alive, player, monster, log}`.
     No monster action occurs yet.

  2. **End turn** — call `end_turn/3` when the player is done (or hand is empty).
     The monster executes its `next_action`; block absorbs damage first.
     Block resets to 0, energy resets to max_energy, and 5 new cards are drawn.
     Returns `{:player_dead | :continue, player, monster, log}`.

  ## Block mechanics
  `player.block` absorbs incoming monster damage before HP is reduced.
  Block resets to 0 at the end of each turn (after the monster acts).

  ## Dodge mechanic
  `player.dodge_next` (set by the Evade card) causes the monster's next
  damage action to be fully dodged (0 damage). The flag is cleared after use.

  The `roller` argument (`fn sides -> integer()`) is injected for determinism in tests.
  """

  alias DungeonGame.{Card, Dice, Loot, Monster}

  @type roller :: Dice.roller()
  @type combatant :: %{
          required(:hp) => integer(),
          required(:armor_class) => integer(),
          required(:damage) => String.t(),
          required(:name) => String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API — play_card/4
  # ---------------------------------------------------------------------------

  @doc """
  Applies a card's effect during the player's turn. Deducts energy, moves the
  card to discard, and applies the card effect.

  Returns:
  - `{:monster_dead, player, monster, log}` — monster slain by this card
  - `{:alive, player, monster, log}` — both survive; keep playing or end turn
  - If the card cost exceeds current energy: `{:alive, player, monster, ["Not enough energy!"]}`
  """
  @spec play_card(map(), map(), %Card{}, roller(), non_neg_integer() | nil) ::
          {:monster_dead | :alive, map(), map(), [String.t()]}
  def play_card(player, monster, card, roller \\ &:rand.uniform/1, hand_idx \\ nil) do
    if card.cost > player.energy do
      {:alive, player, monster, ["Not enough energy to play #{card.name}!"]}
    else
      player =
        player
        |> Map.update!(:energy, &(&1 - card.cost))
        |> Map.update!(:hand, fn hand ->
          if hand_idx, do: List.delete_at(hand, hand_idx), else: List.delete(hand, card)
        end)
        |> Map.update!(:discard, &[card | &1])

      {player, monster, log} = Card.apply(card, player, monster, roller)

      if not alive?(monster) do
        {player, loot_log} = apply_loot(player, monster, roller)
        {:monster_dead, player, monster, log ++ ["The #{monster.name} is defeated!"] ++ loot_log}
      else
        {:alive, player, monster, log}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Public API — end_turn/3
  # ---------------------------------------------------------------------------

  @doc """
  Resolves the end of the player's turn:
  1. Discards remaining hand.
  2. Monster executes its next_action (block absorbs damage; dodge_next skips it).
  3. Resets block to 0, energy to max_energy, dodge_next to false.
  4. Draws 5 new cards (reshuffles discard into deck if needed).

  Returns:
  - `{:player_dead, player, monster, log}` — player killed by monster action
  - `{:continue, player, monster, log}` — both survive; start next turn
  """
  @spec end_turn(map(), map(), roller()) ::
          {:player_dead | :continue, map(), map(), [String.t()]}
  def end_turn(player, monster, roller \\ &:rand.uniform/1) do
    # Discard remaining hand
    player = %{player | discard: player.hand ++ player.discard, hand: []}

    # Resolve monster action
    action = monster.next_action || Monster.pick_action(monster.actions)
    {monster_logs, player, monster} = resolve_monster_action(action, monster, player, roller)

    if not alive?(player) do
      {:player_dead, player, monster, monster_logs ++ ["You have been defeated!"]}
    else
      # Reset per-turn state and draw new hand
      player =
        %{player | block: 0, dodge_next: false, energy: player.max_energy}
        |> draw_hand(5)

      {:continue, player, monster, monster_logs}
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
  # Private — monster action resolution
  # ---------------------------------------------------------------------------

  defp resolve_monster_action(action, monster, player, roller) do
    cond do
      player.dodge_next and damage_action?(action) ->
        player = %{player | dodge_next: false}
        {["👤 You dodge the attack completely!"], player, monster}

      damage_action?(action) ->
        resolve_monster_damage(action, monster, player, roller)

      true ->
        execute_monster_action(action, monster, player, roller)
    end
  end

  defp resolve_monster_damage(action, monster, player, roller) do
    {raw_damage, log_prefix} = calc_monster_damage(action, monster, player, roller)

    if raw_damage > 0 do
      absorbed = min(player.block, raw_damage)
      damage = raw_damage - absorbed
      player = %{player | hp: max(0, player.hp - damage), block: player.block - absorbed}

      block_log =
        if absorbed > 0, do: ["🛡 #{absorbed} blocked! #{damage} damage taken."], else: []

      damage_log =
        if absorbed == 0,
          do: ["#{log_prefix} #{raw_damage} damage."],
          else: []

      {block_log ++ damage_log, player, monster}
    else
      {[log_prefix <> " misses!"], player, monster}
    end
  end

  defp calc_monster_damage(%{type: :attack}, monster, player, roller) do
    roll = roller.(20)
    effective_ac = player.armor_class + Map.get(player, :bonus_ac, 0)

    if roll >= effective_ac do
      damage = Dice.roll(monster.damage, roller)
      {damage, "The #{monster.name} hits you for"}
    else
      {0, "The #{monster.name}"}
    end
  end

  defp calc_monster_damage(%{type: :heavy_attack} = action, monster, _player, roller) do
    damage = Dice.roll(action.damage, roller)
    {damage, "The #{monster.name}'s #{action.name} slams you for"}
  end

  defp calc_monster_damage(%{type: :ranged} = action, monster, _player, roller) do
    damage = Dice.roll(action.damage, roller)
    {damage, "The #{monster.name}'s #{action.name} hits you for"}
  end

  defp execute_monster_action(%{type: :heal} = action, monster, player, roller) do
    amount = Dice.roll(action.amount, roller)
    monster = %{monster | hp: min(monster.max_hp, monster.hp + amount)}
    {["The #{monster.name} uses #{action.name} and recovers #{amount} HP!"], player, monster}
  end

  defp execute_monster_action(%{type: :steal_potion}, monster, player, roller) do
    if player.potions > 0 do
      player = %{player | potions: player.potions - 1}
      {["The #{monster.name} picks your pocket and steals a potion!"], player, monster}
    else
      fake_attack = %{type: :attack}
      resolve_monster_damage(fake_attack, monster, player, roller)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp damage_action?(%{type: type}) when type in [:attack, :heavy_attack, :ranged], do: true
  defp damage_action?(_), do: false

  defp draw_hand(player, n) do
    # If deck has fewer than n cards, reshuffle discard in
    player =
      if length(player.deck) < n and player.discard != [] do
        %{player | deck: Enum.shuffle(player.discard) ++ player.deck, discard: []}
      else
        player
      end

    {new_cards, remaining_deck} = Enum.split(player.deck, n)
    %{player | hand: new_cards, deck: remaining_deck}
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
end
