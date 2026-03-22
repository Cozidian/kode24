defmodule DungeonGame.ClassCombatTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Card, Combat, Monster, PlayerClass}

  defp always(n), do: fn _sides -> n end

  defp attack_only(monster) do
    %{monster | actions: [%{name: "Attack", type: :attack, weight: 1}], next_action: nil}
  end

  defp durable_monster,
    do: attack_only(%{Monster.for_round(1) | hp: 1000, max_hp: 1000, armor_class: 1})

  defp unhittable_monster,
    do: attack_only(%{Monster.for_round(1) | hp: 1000, max_hp: 1000, armor_class: 100})

  defp warrior, do: PlayerClass.new_player(:warrior, "Thor")
  defp rogue, do: PlayerClass.new_player(:rogue, "Shadow")
  defp mage, do: PlayerClass.new_player(:mage, "Gandalf")

  defp card(class, id), do: Enum.find(Card.all(class), &(&1.id == id))

  # ---------------------------------------------------------------------------
  # Warrior — block mechanics
  # ---------------------------------------------------------------------------

  describe "warrior block cards" do
    test "shield_up gains 6 block" do
      player = warrior()
      c = card(:warrior, :shield_up)
      {:alive, updated, _, _} = Combat.play_card(player, durable_monster(), c, always(1))
      assert updated.block == 6
    end

    test "iron_wave deals damage and gains 4 block" do
      player = warrior()
      c = card(:warrior, :iron_wave)

      {:alive, updated_player, updated_monster, _} =
        Combat.play_card(player, durable_monster(), c, always(8))

      assert updated_monster.hp < durable_monster().hp
      assert updated_player.block == 4
    end

    test "shield_slam deals block as damage and clears block" do
      player = %{warrior() | block: 10}
      c = card(:warrior, :shield_slam)

      {:alive, updated_player, updated_monster, _} =
        Combat.play_card(player, durable_monster(), c, always(1))

      assert updated_monster.hp == durable_monster().hp - 10
      assert updated_player.block == 0
    end

    test "bulwark gains 12 block" do
      player = warrior()
      c = card(:warrior, :bulwark)
      {:alive, updated, _, _} = Combat.play_card(player, durable_monster(), c, always(1))
      assert updated.block == 12
    end

    test "block absorbs monster damage at end of turn" do
      player = %{warrior() | block: 100, armor_class: 1}
      strong = %{durable_monster() | damage: "1d4"}
      {:continue, updated_player, _, _} = Combat.end_turn(player, strong, always(4))
      assert updated_player.hp == player.hp
    end

    test "block resets at end of turn" do
      player = %{warrior() | block: 10}
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      assert updated_player.block == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Warrior — battle_cry (draw)
  # ---------------------------------------------------------------------------

  describe "warrior battle_cry" do
    test "draws 2 cards" do
      player = warrior()
      c = card(:warrior, :battle_cry)
      # Ensure battle_cry is in hand (it's a reward card, not in starting deck)
      player = %{player | hand: [c | player.hand]}
      hand_before = length(player.hand)
      {:alive, updated, _, _} = Combat.play_card(player, durable_monster(), c, always(1))
      assert length(updated.hand) == hand_before + 2 - 1
    end
  end

  # ---------------------------------------------------------------------------
  # Rogue — backstab (damage + draw)
  # ---------------------------------------------------------------------------

  describe "rogue backstab" do
    test "deals damage and draws 1 card" do
      player = rogue()
      hand_before = length(player.hand)
      c = card(:rogue, :backstab)

      {:alive, updated_player, updated_monster, _} =
        Combat.play_card(player, durable_monster(), c, always(4))

      assert updated_monster.hp < durable_monster().hp
      assert length(updated_player.hand) == hand_before - 1 + 1
    end
  end

  describe "rogue blade_dance" do
    test "hits 3 times for 1d4 each" do
      player = rogue()
      c = card(:rogue, :blade_dance)

      {:alive, _, updated_monster, log} =
        Combat.play_card(player, durable_monster(), c, always(4))

      assert durable_monster().hp - updated_monster.hp == 12
      assert length(log) == 3
    end
  end

  describe "rogue evade" do
    test "sets dodge_next on player" do
      player = rogue()
      c = card(:rogue, :evade)
      {:alive, updated_player, _, _} = Combat.play_card(player, durable_monster(), c, always(1))
      assert updated_player.dodge_next == true
    end

    test "dodge_next causes monster attack to miss at end_turn" do
      player = %{rogue() | armor_class: 1, dodge_next: true}
      strong = %{durable_monster() | damage: "1d4"}
      {:continue, updated_player, _, log} = Combat.end_turn(player, strong, always(20))
      assert updated_player.hp == player.hp
      assert Enum.any?(log, &String.contains?(&1, "dodge"))
    end
  end

  describe "rogue finisher" do
    test "deals 4d6 damage" do
      player = rogue()
      c = card(:rogue, :finisher)

      {:alive, _, updated_monster, _} =
        Combat.play_card(player, durable_monster(), c, always(6))

      assert durable_monster().hp - updated_monster.hp == 24
    end
  end

  # ---------------------------------------------------------------------------
  # Mage — ignores AC
  # ---------------------------------------------------------------------------

  describe "mage arcane_bolt" do
    test "deals damage ignoring AC" do
      player = mage()
      c = card(:mage, :arcane_bolt)

      {:alive, _, updated_monster, _} =
        Combat.play_card(player, unhittable_monster(), c, always(4))

      assert updated_monster.hp < unhittable_monster().hp
    end
  end

  describe "mage magic_missile" do
    test "deals 1d4+1 damage ignoring AC" do
      player = mage()
      c = card(:mage, :magic_missile)

      {:alive, _, updated_monster, _} =
        Combat.play_card(player, unhittable_monster(), c, always(4))

      assert unhittable_monster().hp - updated_monster.hp == 5
    end
  end

  describe "mage frost_nova" do
    test "deals damage and gains 5 block" do
      player = mage()
      c = card(:mage, :frost_nova)

      {:alive, updated_player, updated_monster, _} =
        Combat.play_card(player, durable_monster(), c, always(6))

      assert updated_monster.hp < durable_monster().hp
      assert updated_player.block == 5
    end
  end

  describe "mage chain_lightning" do
    test "deals 1d8 damage ignoring AC" do
      player = mage()
      c = card(:mage, :chain_lightning)

      {:alive, _, updated_monster, _} =
        Combat.play_card(player, unhittable_monster(), c, always(8))

      assert unhittable_monster().hp - updated_monster.hp == 8
    end
  end

  # ---------------------------------------------------------------------------
  # Energy system
  # ---------------------------------------------------------------------------

  describe "energy" do
    test "playing cards costs energy" do
      player = warrior()
      c = card(:warrior, :cleave)
      {:alive, updated, _, _} = Combat.play_card(player, durable_monster(), c, always(6))
      assert updated.energy == player.energy - c.cost
    end

    test "returns :alive with error when not enough energy" do
      player = %{warrior() | energy: 0}
      c = card(:warrior, :cleave)
      {:alive, unchanged, _, log} = Combat.play_card(player, durable_monster(), c, always(6))
      assert unchanged.energy == 0
      assert Enum.any?(log, &String.contains?(&1, "energy"))
    end

    test "energy resets to max at end of turn" do
      player = %{warrior() | energy: 0}
      {:continue, updated, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      assert updated.energy == player.max_energy
    end
  end

  # ---------------------------------------------------------------------------
  # Monster action types
  # ---------------------------------------------------------------------------

  describe "monster actions during end_turn" do
    test "attack damages player" do
      player = %{warrior() | armor_class: 1, block: 0}
      strong = %{durable_monster() | damage: "1d4"}
      # always(4): d20 roll=4 >= AC 1 (hit), d4 damage=4 — warrior survives (12-4=8)
      {:continue, updated, _, _} = Combat.end_turn(player, strong, always(4))
      assert updated.hp < player.hp
    end

    test "ranged action always damages" do
      monster =
        %{
          durable_monster()
          | actions: [%{name: "Arrow", type: :ranged, damage: "1d4", weight: 1}],
            next_action: nil
        }

      {:continue, updated, _, _} = Combat.end_turn(warrior(), monster, always(4))
      assert updated.hp < warrior().hp
    end

    test "heal action restores monster HP" do
      monster =
        %{
          durable_monster()
          | hp: 5,
            actions: [%{name: "Heal", type: :heal, amount: "1d4", weight: 1}],
            next_action: nil
        }

      {:continue, _, updated_monster, _} = Combat.end_turn(warrior(), monster, always(4))
      assert updated_monster.hp > 5
    end

    test "steal_potion takes a potion" do
      monster =
        %{
          durable_monster()
          | actions: [%{name: "Steal", type: :steal_potion, weight: 1}],
            next_action: nil
        }

      player = %{warrior() | potions: 2, armor_class: 21}
      {:continue, updated, _, _} = Combat.end_turn(player, monster, always(1))
      assert updated.potions == 1
    end
  end
end
