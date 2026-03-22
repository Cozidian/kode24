defmodule DungeonGame.Card do
  @moduledoc """
  Card struct, effect resolution, and the public API for deck building.

  Card data (the full catalog) lives in `DungeonGame.CardCatalog`.

  ## Effect variants
  - `{:damage, dice}`                — roll vs monster AC; deal dice damage on hit
  - `{:damage_nac, dice}`            — deal dice damage ignoring AC
  - `{:block, n}`                    — gain n block
  - `{:damage_and_block, dice, n}`   — damage (vs AC) + gain n block
  - `{:multi_hit, dice, n}`          — n separate attacks of dice each (each vs AC)
  - `:shield_slam`                   — deal current block as damage, clear block
  - `{:draw, n}`                     — draw n cards
  - `:dodge`                         — set dodge_next: true
  - `{:damage_and_draw, dice, n}`    — damage (vs AC) + draw n cards
  - `{:dodge_and_draw, n}`           — dodge next attack + draw n cards
  - `{:block_and_draw, n, m}`        — gain n block + draw m cards
  - `{:damage_nac_and_draw, dice, n}`— damage ignoring AC + draw n cards
  """

  alias DungeonGame.{CardCatalog, Combat, Dice}

  defstruct [:id, :name, :cost, :class, :description, :effect]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "All cards available to `class` (base catalog + extended reward catalog)."
  @spec all(:warrior | :rogue | :mage) :: [%__MODULE__{}]
  def all(:warrior), do: CardCatalog.warrior_base() ++ CardCatalog.warrior_extra()
  def all(:rogue), do: CardCatalog.rogue_base() ++ CardCatalog.rogue_extra()
  def all(:mage), do: CardCatalog.mage_base() ++ CardCatalog.mage_extra()

  @doc "Returns the shuffled 10-card starting deck for `class`."
  @spec starting_deck(:warrior | :rogue | :mage) :: [%__MODULE__{}]
  def starting_deck(:warrior) do
    by_id = card_index(:warrior)

    (List.duplicate(by_id[:cleave], 5) ++
       List.duplicate(by_id[:shield_up], 4) ++
       [by_id[:iron_wave]])
    |> Enum.shuffle()
  end

  def starting_deck(:rogue) do
    by_id = card_index(:rogue)

    (List.duplicate(by_id[:stab], 5) ++
       List.duplicate(by_id[:backstab], 4) ++
       [by_id[:evade]])
    |> Enum.shuffle()
  end

  def starting_deck(:mage) do
    by_id = card_index(:mage)

    (List.duplicate(by_id[:magic_missile], 5) ++
       List.duplicate(by_id[:mana_shield], 4) ++
       [by_id[:frost_nova]])
    |> Enum.shuffle()
  end

  @doc "Returns the 20-card reward pool (post-room choices) for `class`."
  @spec reward_pool(:warrior | :rogue | :mage) :: [%__MODULE__{}]
  def reward_pool(:warrior) do
    by_id = card_index(:warrior)

    [by_id[:bash], by_id[:shield_slam], by_id[:battle_cry], by_id[:bulwark]] ++
      CardCatalog.warrior_extra()
  end

  def reward_pool(:rogue) do
    by_id = card_index(:rogue)

    [by_id[:blade_dance], by_id[:evade], by_id[:finisher], by_id[:preparation]] ++
      CardCatalog.rogue_extra()
  end

  def reward_pool(:mage) do
    by_id = card_index(:mage)

    [by_id[:fireball], by_id[:chain_lightning], by_id[:mana_shield], by_id[:concentration]] ++
      CardCatalog.mage_extra()
  end

  @doc """
  Applies a card's effect to the player and monster.
  Returns `{updated_player, updated_monster, log_entries}`.
  Does NOT deduct energy or move the card — that is Combat's job.
  """
  @spec apply(%__MODULE__{}, map(), map(), Dice.roller()) ::
          {map(), map(), [String.t()]}
  def apply(%__MODULE__{effect: {:damage, dice}} = card, player, monster, roller) do
    apply_damage_vs_ac(card.name, dice, player, monster, roller)
  end

  def apply(%__MODULE__{effect: {:damage_nac, dice}} = card, player, monster, roller) do
    damage = roll_dice(dice, roller)
    monster = Combat.apply_damage(monster, damage)
    {player, monster, ["#{card.name}! #{damage} damage, ignoring armor."]}
  end

  def apply(%__MODULE__{effect: {:block, n}} = card, player, monster, _roller) do
    player = %{player | block: player.block + n}
    {player, monster, ["#{card.name}! Gained #{n} block."]}
  end

  def apply(
        %__MODULE__{effect: {:damage_and_block, dice, block_n}} = card,
        player,
        monster,
        roller
      ) do
    {player, monster, dmg_log} = apply_damage_vs_ac(card.name, dice, player, monster, roller)
    player = %{player | block: player.block + block_n}
    {player, monster, dmg_log ++ ["Gained #{block_n} block."]}
  end

  def apply(%__MODULE__{effect: {:multi_hit, dice, n}} = card, player, monster, roller) do
    {player, monster, logs} =
      Enum.reduce(1..n, {player, monster, []}, fn _i, {p, m, acc_log} ->
        {_p, updated_m, hit_log} = apply_damage_vs_ac(card.name, dice, p, m, roller)
        {p, updated_m, acc_log ++ hit_log}
      end)

    {player, monster, logs}
  end

  def apply(%__MODULE__{effect: :shield_slam} = card, player, monster, _roller) do
    dmg = player.block
    monster = Combat.apply_damage(monster, dmg)
    player = %{player | block: 0}

    log =
      if dmg > 0,
        do: "#{card.name}! #{dmg} damage (cleared all block).",
        else: "#{card.name}! No block to slam with."

    {player, monster, [log]}
  end

  def apply(%__MODULE__{effect: {:draw, n}} = card, player, monster, _roller) do
    {new_hand, new_deck} = Enum.split(player.deck, n)
    player = %{player | hand: player.hand ++ new_hand, deck: new_deck}
    {player, monster, ["#{card.name}! Drew #{length(new_hand)} card(s)."]}
  end

  def apply(%__MODULE__{effect: :dodge} = card, player, monster, _roller) do
    player = %{player | dodge_next: true}
    {player, monster, ["#{card.name}! You ready yourself to dodge the next attack."]}
  end

  def apply(%__MODULE__{effect: {:damage_and_draw, dice, draw_n}} = card, player, monster, roller) do
    {player, monster, dmg_log} = apply_damage_vs_ac(card.name, dice, player, monster, roller)
    {new_hand, new_deck} = Enum.split(player.deck, draw_n)
    player = %{player | hand: player.hand ++ new_hand, deck: new_deck}
    {player, monster, dmg_log ++ ["Drew #{length(new_hand)} card(s)."]}
  end

  def apply(%__MODULE__{effect: {:dodge_and_draw, draw_n}} = card, player, monster, _roller) do
    player = %{player | dodge_next: true}
    {new_hand, new_deck} = Enum.split(player.deck, draw_n)
    player = %{player | hand: player.hand ++ new_hand, deck: new_deck}

    {player, monster,
     [
       "#{card.name}! You ready yourself to dodge the next attack.",
       "Drew #{length(new_hand)} card(s)."
     ]}
  end

  def apply(
        %__MODULE__{effect: {:block_and_draw, block_n, draw_n}} = card,
        player,
        monster,
        _roller
      ) do
    player = %{player | block: player.block + block_n}
    {new_hand, new_deck} = Enum.split(player.deck, draw_n)
    player = %{player | hand: player.hand ++ new_hand, deck: new_deck}

    {player, monster,
     [
       "#{card.name}! Gained #{block_n} block.",
       "Drew #{length(new_hand)} card(s)."
     ]}
  end

  def apply(
        %__MODULE__{effect: {:damage_nac_and_draw, dice, draw_n}} = card,
        player,
        monster,
        roller
      ) do
    damage = roll_dice(dice, roller)
    monster = Combat.apply_damage(monster, damage)
    {new_hand, new_deck} = Enum.split(player.deck, draw_n)
    player = %{player | hand: player.hand ++ new_hand, deck: new_deck}

    {player, monster,
     [
       "#{card.name}! #{damage} damage, ignoring armor.",
       "Drew #{length(new_hand)} card(s)."
     ]}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp apply_damage_vs_ac(name, dice, player, monster, roller) do
    roll = roller.(20)
    effective_ac = monster.armor_class + Map.get(monster, :bonus_ac, 0)

    if roll >= effective_ac do
      damage = roll_dice(dice, roller) + Map.get(player, :bonus_damage, 0)
      monster = Combat.apply_damage(monster, damage)
      {player, monster, ["#{name}! Hit for #{damage} damage."]}
    else
      {player, monster, ["#{name}! Missed."]}
    end
  end

  # Parses simple dice notation: "2d6", "1d4+1"
  defp roll_dice(dice_str, roller) do
    case String.split(dice_str, "+") do
      [dice, bonus_str] ->
        Dice.roll(dice, roller) + String.to_integer(bonus_str)

      [dice] ->
        Dice.roll(dice, roller)
    end
  end

  defp card_index(class) do
    all(class) |> Map.new(&{&1.id, &1})
  end
end
