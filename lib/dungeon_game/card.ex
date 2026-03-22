defmodule DungeonGame.Card do
  @moduledoc """
  Class-specific card system. Each class has a starting deck of 10 cards plus
  a reward pool of 20 cards that can be added to the deck after clearing a room.

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

  alias DungeonGame.{Combat, Dice}

  defstruct [:id, :name, :cost, :class, :description, :effect]

  # ---------------------------------------------------------------------------
  # Base catalogs (starting-deck cards + classic reward cards)
  # ---------------------------------------------------------------------------

  defp warrior_cards do
    [
      %__MODULE__{
        id: :cleave,
        name: "Cleave",
        cost: 1,
        class: :warrior,
        description: "Deal 1d8 damage.",
        effect: {:damage, "1d8"}
      },
      %__MODULE__{
        id: :shield_up,
        name: "Shield Up",
        cost: 1,
        class: :warrior,
        description: "Gain 6 block.",
        effect: {:block, 6}
      },
      %__MODULE__{
        id: :iron_wave,
        name: "Iron Wave",
        cost: 1,
        class: :warrior,
        description: "Deal 1d6 damage and gain 4 block.",
        effect: {:damage_and_block, "1d6", 4}
      },
      %__MODULE__{
        id: :bash,
        name: "Bash",
        cost: 2,
        class: :warrior,
        description: "Deal 3d6 damage — a bone-shattering blow.",
        effect: {:damage, "3d6"}
      },
      %__MODULE__{
        id: :shield_slam,
        name: "Shield Slam",
        cost: 2,
        class: :warrior,
        description: "Deal damage equal to your current block, then lose all block.",
        effect: :shield_slam
      },
      %__MODULE__{
        id: :battle_cry,
        name: "Battle Cry",
        cost: 0,
        class: :warrior,
        description: "Draw 2 cards.",
        effect: {:draw, 2}
      },
      %__MODULE__{
        id: :bulwark,
        name: "Bulwark",
        cost: 2,
        class: :warrior,
        description: "Gain 12 block — turtle behind your shield.",
        effect: {:block, 12}
      }
    ]
  end

  defp rogue_cards do
    [
      %__MODULE__{
        id: :stab,
        name: "Stab",
        cost: 1,
        class: :rogue,
        description: "Deal 1d6 damage.",
        effect: {:damage, "1d6"}
      },
      %__MODULE__{
        id: :backstab,
        name: "Backstab",
        cost: 0,
        class: :rogue,
        description: "Deal 1d4 damage and draw 1 card.",
        effect: {:damage_and_draw, "1d4", 1}
      },
      %__MODULE__{
        id: :blade_dance,
        name: "Blade Dance",
        cost: 1,
        class: :rogue,
        description: "Strike 3 times for 1d4 each — a whirlwind of cuts.",
        effect: {:multi_hit, "1d4", 3}
      },
      %__MODULE__{
        id: :evade,
        name: "Evade",
        cost: 1,
        class: :rogue,
        description: "Dodge the next monster attack.",
        effect: :dodge
      },
      %__MODULE__{
        id: :finisher,
        name: "Finisher",
        cost: 2,
        class: :rogue,
        description: "Deal 4d6 damage — a devastating killing blow.",
        effect: {:damage, "4d6"}
      },
      %__MODULE__{
        id: :preparation,
        name: "Preparation",
        cost: 1,
        class: :rogue,
        description: "Draw 3 cards.",
        effect: {:draw, 3}
      },
      %__MODULE__{
        id: :cheap_shot,
        name: "Cheap Shot",
        cost: 0,
        class: :rogue,
        description: "Deal 1d4 damage — a quick opportunistic strike.",
        effect: {:damage, "1d4"}
      }
    ]
  end

  defp mage_cards do
    [
      %__MODULE__{
        id: :magic_missile,
        name: "Magic Missile",
        cost: 1,
        class: :mage,
        description: "Deal 1d4+1 damage, ignoring armor.",
        effect: {:damage_nac, "1d4+1"}
      },
      %__MODULE__{
        id: :fireball,
        name: "Fireball",
        cost: 2,
        class: :mage,
        description: "Hurl a roaring sphere of fire for 2d8 damage.",
        effect: {:damage, "2d8"}
      },
      %__MODULE__{
        id: :frost_nova,
        name: "Frost Nova",
        cost: 1,
        class: :mage,
        description: "Deal 1d6 damage and gain 5 block from the icy burst.",
        effect: {:damage_and_block, "1d6", 5}
      },
      %__MODULE__{
        id: :arcane_bolt,
        name: "Arcane Bolt",
        cost: 0,
        class: :mage,
        description: "A quick arcane discharge for 1d4 damage, ignoring armor.",
        effect: {:damage_nac, "1d4"}
      },
      %__MODULE__{
        id: :chain_lightning,
        name: "Chain Lightning",
        cost: 2,
        class: :mage,
        description: "Arc lightning for 1d8 damage, ignoring armor.",
        effect: {:damage_nac, "1d8"}
      },
      %__MODULE__{
        id: :mana_shield,
        name: "Mana Shield",
        cost: 1,
        class: :mage,
        description: "Conjure a shimmering arcane barrier — gain 8 block.",
        effect: {:block, 8}
      },
      %__MODULE__{
        id: :concentration,
        name: "Concentration",
        cost: 0,
        class: :mage,
        description: "Focus your mind — draw 2 cards.",
        effect: {:draw, 2}
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Extended reward catalogs (16 unique cards per class)
  # ---------------------------------------------------------------------------

  defp warrior_extra_cards do
    [
      %__MODULE__{
        id: :whirlwind,
        name: "Whirlwind",
        cost: 2,
        class: :warrior,
        description: "Spin your blade — strike 3 times for 1d6 each.",
        effect: {:multi_hit, "1d6", 3}
      },
      %__MODULE__{
        id: :power_strike,
        name: "Power Strike",
        cost: 2,
        class: :warrior,
        description: "Channel your strength into a devastating 4d6 blow.",
        effect: {:damage, "4d6"}
      },
      %__MODULE__{
        id: :headbutt,
        name: "Headbutt",
        cost: 1,
        class: :warrior,
        description: "Ram your helmet into the foe for 2d4 damage.",
        effect: {:damage, "2d4"}
      },
      %__MODULE__{
        id: :fortify,
        name: "Fortify",
        cost: 1,
        class: :warrior,
        description: "Brace yourself — gain 5 block and draw 1 card.",
        effect: {:block_and_draw, 5, 1}
      },
      %__MODULE__{
        id: :retaliate,
        name: "Retaliate",
        cost: 1,
        class: :warrior,
        description: "Strike for 1d6 damage and raise your guard for 6 block.",
        effect: {:damage_and_block, "1d6", 6}
      },
      %__MODULE__{
        id: :dual_strike,
        name: "Dual Strike",
        cost: 1,
        class: :warrior,
        description: "Two swift strikes for 1d6 each.",
        effect: {:multi_hit, "1d6", 2}
      },
      %__MODULE__{
        id: :berserker_rage,
        name: "Berserker Rage",
        cost: 3,
        class: :warrior,
        description: "Unleash unbridled fury — 5d6 damage.",
        effect: {:damage, "5d6"}
      },
      %__MODULE__{
        id: :ground_slam,
        name: "Ground Slam",
        cost: 2,
        class: :warrior,
        description: "Slam the earth, sending shockwaves for 2d8 damage.",
        effect: {:damage, "2d8"}
      },
      %__MODULE__{
        id: :rally,
        name: "Rally",
        cost: 1,
        class: :warrior,
        description: "Rally your spirit — gain 3 block and draw 2 cards.",
        effect: {:block_and_draw, 3, 2}
      },
      %__MODULE__{
        id: :impale,
        name: "Impale",
        cost: 2,
        class: :warrior,
        description: "Drive your weapon deep for 3d8 damage.",
        effect: {:damage, "3d8"}
      },
      %__MODULE__{
        id: :war_cry,
        name: "War Cry",
        cost: 0,
        class: :warrior,
        description: "Bellow a mighty war cry — draw 3 cards.",
        effect: {:draw, 3}
      },
      %__MODULE__{
        id: :shield_bash,
        name: "Shield Bash",
        cost: 1,
        class: :warrior,
        description: "Bash with your shield — 1d4 damage and gain 5 block.",
        effect: {:damage_and_block, "1d4", 5}
      },
      %__MODULE__{
        id: :intimidate,
        name: "Intimidate",
        cost: 0,
        class: :warrior,
        description: "Flex and roar — gain 4 block for free.",
        effect: {:block, 4}
      },
      %__MODULE__{
        id: :last_stand,
        name: "Last Stand",
        cost: 3,
        class: :warrior,
        description: "Plant your feet and refuse to fall — gain 20 block.",
        effect: {:block, 20}
      },
      %__MODULE__{
        id: :defender,
        name: "Defender",
        cost: 1,
        class: :warrior,
        description: "Strike for 1d8 damage and fortify with 3 block.",
        effect: {:damage_and_block, "1d8", 3}
      },
      %__MODULE__{
        id: :titan_strike,
        name: "Titan Strike",
        cost: 3,
        class: :warrior,
        description: "A cataclysmic blow worthy of a titan — 6d6 damage.",
        effect: {:damage, "6d6"}
      }
    ]
  end

  defp rogue_extra_cards do
    [
      %__MODULE__{
        id: :assassinate,
        name: "Assassinate",
        cost: 2,
        class: :rogue,
        description: "Strike from the shadows for a devastating 5d6 blow.",
        effect: {:damage, "5d6"}
      },
      %__MODULE__{
        id: :caltrops,
        name: "Caltrops",
        cost: 1,
        class: :rogue,
        description: "Scatter caltrops — 5 hits of 1d4 damage each.",
        effect: {:multi_hit, "1d4", 5}
      },
      %__MODULE__{
        id: :hemorrhage,
        name: "Hemorrhage",
        cost: 2,
        class: :rogue,
        description: "Open a grievous wound for 3d8 damage.",
        effect: {:damage, "3d8"}
      },
      %__MODULE__{
        id: :lacerate,
        name: "Lacerate",
        cost: 1,
        class: :rogue,
        description: "Slash twice for 1d6 each — leave them bleeding.",
        effect: {:multi_hit, "1d6", 2}
      },
      %__MODULE__{
        id: :shadow_step,
        name: "Shadow Step",
        cost: 0,
        class: :rogue,
        description: "Step through shadows — dodge the next attack and draw 1 card.",
        effect: {:dodge_and_draw, 1}
      },
      %__MODULE__{
        id: :smoke_bomb,
        name: "Smoke Bomb",
        cost: 1,
        class: :rogue,
        description: "Throw a smoke bomb — dodge the next attack and draw 2 cards.",
        effect: {:dodge_and_draw, 2}
      },
      %__MODULE__{
        id: :fan_of_knives,
        name: "Fan of Knives",
        cost: 2,
        class: :rogue,
        description: "Hurl a fan of blades — 4 strikes for 1d6 each.",
        effect: {:multi_hit, "1d6", 4}
      },
      %__MODULE__{
        id: :quick_reflexes,
        name: "Quick Reflexes",
        cost: 0,
        class: :rogue,
        description: "React with lightning speed — draw 2 cards.",
        effect: {:draw, 2}
      },
      %__MODULE__{
        id: :venomous_strike,
        name: "Venomous Strike",
        cost: 1,
        class: :rogue,
        description: "A poisoned strike for 1d6 damage, then draw 1 card.",
        effect: {:damage_and_draw, "1d6", 1}
      },
      %__MODULE__{
        id: :coup_de_grace,
        name: "Coup de Grâce",
        cost: 3,
        class: :rogue,
        description: "The perfect killing blow — 6d6 damage.",
        effect: {:damage, "6d6"}
      },
      %__MODULE__{
        id: :shadowmeld,
        name: "Shadowmeld",
        cost: 2,
        class: :rogue,
        description: "Meld into the shadows — dodge next attack and draw 3 cards.",
        effect: {:dodge_and_draw, 3}
      },
      %__MODULE__{
        id: :adrenaline,
        name: "Adrenaline",
        cost: 0,
        class: :rogue,
        description: "Your veins surge with adrenaline — draw 3 cards.",
        effect: {:draw, 3}
      },
      %__MODULE__{
        id: :throat_cut,
        name: "Throat Cut",
        cost: 2,
        class: :rogue,
        description: "A precise cut to the throat — 3d6 damage.",
        effect: {:damage, "3d6"}
      },
      %__MODULE__{
        id: :acrobatics,
        name: "Acrobatics",
        cost: 1,
        class: :rogue,
        description: "Flip and weave — gain 4 block and draw 1 card.",
        effect: {:block_and_draw, 4, 1}
      },
      %__MODULE__{
        id: :ambush,
        name: "Ambush",
        cost: 1,
        class: :rogue,
        description: "Strike from concealment for 2d4 damage.",
        effect: {:damage, "2d4"}
      },
      %__MODULE__{
        id: :shadow_arts,
        name: "Shadow Arts",
        cost: 2,
        class: :rogue,
        description: "Three masterful shadow strikes — 1d8 each.",
        effect: {:multi_hit, "1d8", 3}
      }
    ]
  end

  defp mage_extra_cards do
    [
      %__MODULE__{
        id: :meteor,
        name: "Meteor",
        cost: 3,
        class: :mage,
        description: "Call down a fiery meteor for 4d8 damage.",
        effect: {:damage, "4d8"}
      },
      %__MODULE__{
        id: :ice_lance,
        name: "Ice Lance",
        cost: 1,
        class: :mage,
        description: "Pierce with crystalline ice — 2d6 damage, ignoring armor.",
        effect: {:damage_nac, "2d6"}
      },
      %__MODULE__{
        id: :thunderclap,
        name: "Thunderclap",
        cost: 2,
        class: :mage,
        description: "A crack of thunder for 3d6 arcane damage, ignoring armor.",
        effect: {:damage_nac, "3d6"}
      },
      %__MODULE__{
        id: :time_warp,
        name: "Time Warp",
        cost: 0,
        class: :mage,
        description: "Bend time to draw 3 extra cards.",
        effect: {:draw, 3}
      },
      %__MODULE__{
        id: :arcane_surge,
        name: "Arcane Surge",
        cost: 1,
        class: :mage,
        description: "A surge of arcane energy — 2d4 damage ignoring armor, draw 1 card.",
        effect: {:damage_nac_and_draw, "2d4", 1}
      },
      %__MODULE__{
        id: :blizzard,
        name: "Blizzard",
        cost: 2,
        class: :mage,
        description: "Conjure a blizzard for 4d4 cold damage, ignoring armor.",
        effect: {:damage_nac, "4d4"}
      },
      %__MODULE__{
        id: :fire_bolt,
        name: "Fire Bolt",
        cost: 1,
        class: :mage,
        description: "Hurl a searing bolt of fire for 2d6 damage.",
        effect: {:damage, "2d6"}
      },
      %__MODULE__{
        id: :frost_armor,
        name: "Frost Armor",
        cost: 2,
        class: :mage,
        description: "Encase yourself in ice — gain 16 block.",
        effect: {:block, 16}
      },
      %__MODULE__{
        id: :mirror_image,
        name: "Mirror Image",
        cost: 1,
        class: :mage,
        description: "Create illusory doubles — dodge the next attack and draw 1 card.",
        effect: {:dodge_and_draw, 1}
      },
      %__MODULE__{
        id: :power_word,
        name: "Power Word",
        cost: 3,
        class: :mage,
        description: "A word of pure power — 5d6 damage, ignoring armor.",
        effect: {:damage_nac, "5d6"}
      },
      %__MODULE__{
        id: :arcane_intellect,
        name: "Arcane Intellect",
        cost: 0,
        class: :mage,
        description: "Channel pure intellect — draw 4 cards for free.",
        effect: {:draw, 4}
      },
      %__MODULE__{
        id: :glacial_spike,
        name: "Glacial Spike",
        cost: 2,
        class: :mage,
        description: "A spike of glacial ice — 3d8 cold damage, ignoring armor.",
        effect: {:damage_nac, "3d8"}
      },
      %__MODULE__{
        id: :mana_void,
        name: "Mana Void",
        cost: 1,
        class: :mage,
        description: "Redirect raw mana — gain 5 block and draw 1 card.",
        effect: {:block_and_draw, 5, 1}
      },
      %__MODULE__{
        id: :force_of_will,
        name: "Force of Will",
        cost: 2,
        class: :mage,
        description: "Impose your will on reality — 4d6 force damage, ignoring armor.",
        effect: {:damage_nac, "4d6"}
      },
      %__MODULE__{
        id: :hex,
        name: "Hex",
        cost: 1,
        class: :mage,
        description: "Curse the enemy — 1d4 damage ignoring armor, then draw 1 card.",
        effect: {:damage_nac_and_draw, "1d4", 1}
      },
      %__MODULE__{
        id: :lightning_bolt,
        name: "Lightning Bolt",
        cost: 2,
        class: :mage,
        description: "Call down lightning for 3d6 damage.",
        effect: {:damage, "3d6"}
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "All cards available to `class` (base catalog + extended reward catalog)."
  @spec all(:warrior | :rogue | :mage) :: [%__MODULE__{}]
  def all(:warrior), do: warrior_cards() ++ warrior_extra_cards()
  def all(:rogue), do: rogue_cards() ++ rogue_extra_cards()
  def all(:mage), do: mage_cards() ++ mage_extra_cards()

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
      warrior_extra_cards()
  end

  def reward_pool(:rogue) do
    by_id = card_index(:rogue)

    [by_id[:blade_dance], by_id[:evade], by_id[:finisher], by_id[:preparation]] ++
      rogue_extra_cards()
  end

  def reward_pool(:mage) do
    by_id = card_index(:mage)

    [by_id[:fireball], by_id[:chain_lightning], by_id[:mana_shield], by_id[:concentration]] ++
      mage_extra_cards()
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
        DungeonGame.Dice.roll(dice, roller) + String.to_integer(bonus_str)

      [dice] ->
        DungeonGame.Dice.roll(dice, roller)
    end
  end

  defp card_index(class) do
    all(class) |> Map.new(&{&1.id, &1})
  end
end
