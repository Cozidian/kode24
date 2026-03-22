defmodule DungeonGame.CardCatalog do
  @moduledoc """
  Static card definitions for all three classes.

  Each class has:
  - A base set of 7 cards (used to build the starting deck)
  - An extended set of 16 reward-only cards

  This module is purely data — no game logic lives here.
  Use `DungeonGame.Card` for the public API and effect resolution.
  """

  alias DungeonGame.Card

  # ---------------------------------------------------------------------------
  # Warrior
  # ---------------------------------------------------------------------------

  @doc "The 7 base Warrior cards (starting deck pool + classic rewards)."
  def warrior_base do
    [
      %Card{
        id: :cleave,
        name: "Cleave",
        cost: 1,
        class: :warrior,
        description: "Deal 1d8 damage.",
        effect: {:damage, "1d8"}
      },
      %Card{
        id: :shield_up,
        name: "Shield Up",
        cost: 1,
        class: :warrior,
        description: "Gain 6 block.",
        effect: {:block, 6}
      },
      %Card{
        id: :iron_wave,
        name: "Iron Wave",
        cost: 1,
        class: :warrior,
        description: "Deal 1d6 damage and gain 4 block.",
        effect: {:damage_and_block, "1d6", 4}
      },
      %Card{
        id: :bash,
        name: "Bash",
        cost: 2,
        class: :warrior,
        description: "Deal 3d6 damage — a bone-shattering blow.",
        effect: {:damage, "3d6"}
      },
      %Card{
        id: :shield_slam,
        name: "Shield Slam",
        cost: 2,
        class: :warrior,
        description: "Deal damage equal to your current block, then lose all block.",
        effect: :shield_slam
      },
      %Card{
        id: :battle_cry,
        name: "Battle Cry",
        cost: 0,
        class: :warrior,
        description: "Draw 2 cards.",
        effect: {:draw, 2}
      },
      %Card{
        id: :bulwark,
        name: "Bulwark",
        cost: 2,
        class: :warrior,
        description: "Gain 12 block — turtle behind your shield.",
        effect: {:block, 12}
      }
    ]
  end

  @doc "The 16 extended Warrior reward cards."
  def warrior_extra do
    [
      %Card{
        id: :whirlwind,
        name: "Whirlwind",
        cost: 2,
        class: :warrior,
        description: "Spin your blade — strike 3 times for 1d6 each.",
        effect: {:multi_hit, "1d6", 3}
      },
      %Card{
        id: :power_strike,
        name: "Power Strike",
        cost: 2,
        class: :warrior,
        description: "Channel your strength into a devastating 4d6 blow.",
        effect: {:damage, "4d6"}
      },
      %Card{
        id: :headbutt,
        name: "Headbutt",
        cost: 1,
        class: :warrior,
        description: "Ram your helmet into the foe for 2d4 damage.",
        effect: {:damage, "2d4"}
      },
      %Card{
        id: :fortify,
        name: "Fortify",
        cost: 1,
        class: :warrior,
        description: "Brace yourself — gain 5 block and draw 1 card.",
        effect: {:block_and_draw, 5, 1}
      },
      %Card{
        id: :retaliate,
        name: "Retaliate",
        cost: 1,
        class: :warrior,
        description: "Strike for 1d6 damage and raise your guard for 6 block.",
        effect: {:damage_and_block, "1d6", 6}
      },
      %Card{
        id: :dual_strike,
        name: "Dual Strike",
        cost: 1,
        class: :warrior,
        description: "Two swift strikes for 1d6 each.",
        effect: {:multi_hit, "1d6", 2}
      },
      %Card{
        id: :berserker_rage,
        name: "Berserker Rage",
        cost: 3,
        class: :warrior,
        description: "Unleash unbridled fury — 5d6 damage.",
        effect: {:damage, "5d6"}
      },
      %Card{
        id: :ground_slam,
        name: "Ground Slam",
        cost: 2,
        class: :warrior,
        description: "Slam the earth, sending shockwaves for 2d8 damage.",
        effect: {:damage, "2d8"}
      },
      %Card{
        id: :rally,
        name: "Rally",
        cost: 1,
        class: :warrior,
        description: "Rally your spirit — gain 3 block and draw 2 cards.",
        effect: {:block_and_draw, 3, 2}
      },
      %Card{
        id: :impale,
        name: "Impale",
        cost: 2,
        class: :warrior,
        description: "Drive your weapon deep for 3d8 damage.",
        effect: {:damage, "3d8"}
      },
      %Card{
        id: :war_cry,
        name: "War Cry",
        cost: 0,
        class: :warrior,
        description: "Bellow a mighty war cry — draw 3 cards.",
        effect: {:draw, 3}
      },
      %Card{
        id: :shield_bash,
        name: "Shield Bash",
        cost: 1,
        class: :warrior,
        description: "Bash with your shield — 1d4 damage and gain 5 block.",
        effect: {:damage_and_block, "1d4", 5}
      },
      %Card{
        id: :intimidate,
        name: "Intimidate",
        cost: 0,
        class: :warrior,
        description: "Flex and roar — gain 4 block for free.",
        effect: {:block, 4}
      },
      %Card{
        id: :last_stand,
        name: "Last Stand",
        cost: 3,
        class: :warrior,
        description: "Plant your feet and refuse to fall — gain 20 block.",
        effect: {:block, 20}
      },
      %Card{
        id: :defender,
        name: "Defender",
        cost: 1,
        class: :warrior,
        description: "Strike for 1d8 damage and fortify with 3 block.",
        effect: {:damage_and_block, "1d8", 3}
      },
      %Card{
        id: :titan_strike,
        name: "Titan Strike",
        cost: 3,
        class: :warrior,
        description: "A cataclysmic blow worthy of a titan — 6d6 damage.",
        effect: {:damage, "6d6"}
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Rogue
  # ---------------------------------------------------------------------------

  @doc "The 7 base Rogue cards (starting deck pool + classic rewards)."
  def rogue_base do
    [
      %Card{
        id: :stab,
        name: "Stab",
        cost: 1,
        class: :rogue,
        description: "Deal 1d6 damage.",
        effect: {:damage, "1d6"}
      },
      %Card{
        id: :backstab,
        name: "Backstab",
        cost: 0,
        class: :rogue,
        description: "Deal 1d4 damage and draw 1 card.",
        effect: {:damage_and_draw, "1d4", 1}
      },
      %Card{
        id: :blade_dance,
        name: "Blade Dance",
        cost: 1,
        class: :rogue,
        description: "Strike 3 times for 1d4 each — a whirlwind of cuts.",
        effect: {:multi_hit, "1d4", 3}
      },
      %Card{
        id: :evade,
        name: "Evade",
        cost: 1,
        class: :rogue,
        description: "Dodge the next monster attack.",
        effect: :dodge
      },
      %Card{
        id: :finisher,
        name: "Finisher",
        cost: 2,
        class: :rogue,
        description: "Deal 4d6 damage — a devastating killing blow.",
        effect: {:damage, "4d6"}
      },
      %Card{
        id: :preparation,
        name: "Preparation",
        cost: 1,
        class: :rogue,
        description: "Draw 3 cards.",
        effect: {:draw, 3}
      },
      %Card{
        id: :cheap_shot,
        name: "Cheap Shot",
        cost: 0,
        class: :rogue,
        description: "Deal 1d4 damage — a quick opportunistic strike.",
        effect: {:damage, "1d4"}
      }
    ]
  end

  @doc "The 16 extended Rogue reward cards."
  def rogue_extra do
    [
      %Card{
        id: :assassinate,
        name: "Assassinate",
        cost: 2,
        class: :rogue,
        description: "Strike from the shadows for a devastating 5d6 blow.",
        effect: {:damage, "5d6"}
      },
      %Card{
        id: :caltrops,
        name: "Caltrops",
        cost: 1,
        class: :rogue,
        description: "Scatter caltrops — 5 hits of 1d4 damage each.",
        effect: {:multi_hit, "1d4", 5}
      },
      %Card{
        id: :hemorrhage,
        name: "Hemorrhage",
        cost: 2,
        class: :rogue,
        description: "Open a grievous wound for 3d8 damage.",
        effect: {:damage, "3d8"}
      },
      %Card{
        id: :lacerate,
        name: "Lacerate",
        cost: 1,
        class: :rogue,
        description: "Slash twice for 1d6 each — leave them bleeding.",
        effect: {:multi_hit, "1d6", 2}
      },
      %Card{
        id: :shadow_step,
        name: "Shadow Step",
        cost: 0,
        class: :rogue,
        description: "Step through shadows — dodge the next attack and draw 1 card.",
        effect: {:dodge_and_draw, 1}
      },
      %Card{
        id: :smoke_bomb,
        name: "Smoke Bomb",
        cost: 1,
        class: :rogue,
        description: "Throw a smoke bomb — dodge the next attack and draw 2 cards.",
        effect: {:dodge_and_draw, 2}
      },
      %Card{
        id: :fan_of_knives,
        name: "Fan of Knives",
        cost: 2,
        class: :rogue,
        description: "Hurl a fan of blades — 4 strikes for 1d6 each.",
        effect: {:multi_hit, "1d6", 4}
      },
      %Card{
        id: :quick_reflexes,
        name: "Quick Reflexes",
        cost: 0,
        class: :rogue,
        description: "React with lightning speed — draw 2 cards.",
        effect: {:draw, 2}
      },
      %Card{
        id: :venomous_strike,
        name: "Venomous Strike",
        cost: 1,
        class: :rogue,
        description: "A poisoned strike for 1d6 damage, then draw 1 card.",
        effect: {:damage_and_draw, "1d6", 1}
      },
      %Card{
        id: :coup_de_grace,
        name: "Coup de Grâce",
        cost: 3,
        class: :rogue,
        description: "The perfect killing blow — 6d6 damage.",
        effect: {:damage, "6d6"}
      },
      %Card{
        id: :shadowmeld,
        name: "Shadowmeld",
        cost: 2,
        class: :rogue,
        description: "Meld into the shadows — dodge next attack and draw 3 cards.",
        effect: {:dodge_and_draw, 3}
      },
      %Card{
        id: :adrenaline,
        name: "Adrenaline",
        cost: 0,
        class: :rogue,
        description: "Your veins surge with adrenaline — draw 3 cards.",
        effect: {:draw, 3}
      },
      %Card{
        id: :throat_cut,
        name: "Throat Cut",
        cost: 2,
        class: :rogue,
        description: "A precise cut to the throat — 3d6 damage.",
        effect: {:damage, "3d6"}
      },
      %Card{
        id: :acrobatics,
        name: "Acrobatics",
        cost: 1,
        class: :rogue,
        description: "Flip and weave — gain 4 block and draw 1 card.",
        effect: {:block_and_draw, 4, 1}
      },
      %Card{
        id: :ambush,
        name: "Ambush",
        cost: 1,
        class: :rogue,
        description: "Strike from concealment for 2d4 damage.",
        effect: {:damage, "2d4"}
      },
      %Card{
        id: :shadow_arts,
        name: "Shadow Arts",
        cost: 2,
        class: :rogue,
        description: "Three masterful shadow strikes — 1d8 each.",
        effect: {:multi_hit, "1d8", 3}
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Mage
  # ---------------------------------------------------------------------------

  @doc "The 7 base Mage cards (starting deck pool + classic rewards)."
  def mage_base do
    [
      %Card{
        id: :magic_missile,
        name: "Magic Missile",
        cost: 1,
        class: :mage,
        description: "Deal 1d4+1 damage, ignoring armor.",
        effect: {:damage_nac, "1d4+1"}
      },
      %Card{
        id: :fireball,
        name: "Fireball",
        cost: 2,
        class: :mage,
        description: "Hurl a roaring sphere of fire for 2d8 damage.",
        effect: {:damage, "2d8"}
      },
      %Card{
        id: :frost_nova,
        name: "Frost Nova",
        cost: 1,
        class: :mage,
        description: "Deal 1d6 damage and gain 5 block from the icy burst.",
        effect: {:damage_and_block, "1d6", 5}
      },
      %Card{
        id: :arcane_bolt,
        name: "Arcane Bolt",
        cost: 0,
        class: :mage,
        description: "A quick arcane discharge for 1d4 damage, ignoring armor.",
        effect: {:damage_nac, "1d4"}
      },
      %Card{
        id: :chain_lightning,
        name: "Chain Lightning",
        cost: 2,
        class: :mage,
        description: "Arc lightning for 1d8 damage, ignoring armor.",
        effect: {:damage_nac, "1d8"}
      },
      %Card{
        id: :mana_shield,
        name: "Mana Shield",
        cost: 1,
        class: :mage,
        description: "Conjure a shimmering arcane barrier — gain 8 block.",
        effect: {:block, 8}
      },
      %Card{
        id: :concentration,
        name: "Concentration",
        cost: 0,
        class: :mage,
        description: "Focus your mind — draw 2 cards.",
        effect: {:draw, 2}
      }
    ]
  end

  @doc "The 16 extended Mage reward cards."
  def mage_extra do
    [
      %Card{
        id: :meteor,
        name: "Meteor",
        cost: 3,
        class: :mage,
        description: "Call down a fiery meteor for 4d8 damage.",
        effect: {:damage, "4d8"}
      },
      %Card{
        id: :ice_lance,
        name: "Ice Lance",
        cost: 1,
        class: :mage,
        description: "Pierce with crystalline ice — 2d6 damage, ignoring armor.",
        effect: {:damage_nac, "2d6"}
      },
      %Card{
        id: :thunderclap,
        name: "Thunderclap",
        cost: 2,
        class: :mage,
        description: "A crack of thunder for 3d6 arcane damage, ignoring armor.",
        effect: {:damage_nac, "3d6"}
      },
      %Card{
        id: :time_warp,
        name: "Time Warp",
        cost: 0,
        class: :mage,
        description: "Bend time to draw 3 extra cards.",
        effect: {:draw, 3}
      },
      %Card{
        id: :arcane_surge,
        name: "Arcane Surge",
        cost: 1,
        class: :mage,
        description: "A surge of arcane energy — 2d4 damage ignoring armor, draw 1 card.",
        effect: {:damage_nac_and_draw, "2d4", 1}
      },
      %Card{
        id: :blizzard,
        name: "Blizzard",
        cost: 2,
        class: :mage,
        description: "Conjure a blizzard for 4d4 cold damage, ignoring armor.",
        effect: {:damage_nac, "4d4"}
      },
      %Card{
        id: :fire_bolt,
        name: "Fire Bolt",
        cost: 1,
        class: :mage,
        description: "Hurl a searing bolt of fire for 2d6 damage.",
        effect: {:damage, "2d6"}
      },
      %Card{
        id: :frost_armor,
        name: "Frost Armor",
        cost: 2,
        class: :mage,
        description: "Encase yourself in ice — gain 16 block.",
        effect: {:block, 16}
      },
      %Card{
        id: :mirror_image,
        name: "Mirror Image",
        cost: 1,
        class: :mage,
        description: "Create illusory doubles — dodge the next attack and draw 1 card.",
        effect: {:dodge_and_draw, 1}
      },
      %Card{
        id: :power_word,
        name: "Power Word",
        cost: 3,
        class: :mage,
        description: "A word of pure power — 5d6 damage, ignoring armor.",
        effect: {:damage_nac, "5d6"}
      },
      %Card{
        id: :arcane_intellect,
        name: "Arcane Intellect",
        cost: 0,
        class: :mage,
        description: "Channel pure intellect — draw 4 cards for free.",
        effect: {:draw, 4}
      },
      %Card{
        id: :glacial_spike,
        name: "Glacial Spike",
        cost: 2,
        class: :mage,
        description: "A spike of glacial ice — 3d8 cold damage, ignoring armor.",
        effect: {:damage_nac, "3d8"}
      },
      %Card{
        id: :mana_void,
        name: "Mana Void",
        cost: 1,
        class: :mage,
        description: "Redirect raw mana — gain 5 block and draw 1 card.",
        effect: {:block_and_draw, 5, 1}
      },
      %Card{
        id: :force_of_will,
        name: "Force of Will",
        cost: 2,
        class: :mage,
        description: "Impose your will on reality — 4d6 force damage, ignoring armor.",
        effect: {:damage_nac, "4d6"}
      },
      %Card{
        id: :hex,
        name: "Hex",
        cost: 1,
        class: :mage,
        description: "Curse the enemy — 1d4 damage ignoring armor, then draw 1 card.",
        effect: {:damage_nac_and_draw, "1d4", 1}
      },
      %Card{
        id: :lightning_bolt,
        name: "Lightning Bolt",
        cost: 2,
        class: :mage,
        description: "Call down lightning for 3d6 damage.",
        effect: {:damage, "3d6"}
      }
    ]
  end
end
