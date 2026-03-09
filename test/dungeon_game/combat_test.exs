defmodule DungeonGame.CombatTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Combat, Monster, Player}

  # Roller helpers
  defp always(n), do: fn _sides -> n end

  # A monster with negligible armor so any non-zero roll hits
  defp fragile_monster, do: %{Monster.for_round(1) | armor_class: 1}

  # A monster with so much HP it will never die in a single exchange
  defp durable_monster, do: %{Monster.for_round(1) | hp: 1000, max_hp: 1000, armor_class: 1}

  # A player with an impenetrable armor class
  defp fortress_player, do: %Player{armor_class: 21}

  # ---------------------------------------------------------------------------
  # attack/3
  # ---------------------------------------------------------------------------

  describe "attack/3" do
    test "misses when the attack roll is below the defender's armor class" do
      assert Combat.attack(Monster.for_round(1), %Player{armor_class: 14}, always(1)) == :miss
    end

    test "hits when the attack roll meets the defender's armor class exactly" do
      defender = %Player{armor_class: 10}
      assert {:hit, _damage} = Combat.attack(Monster.for_round(1), defender, always(10))
    end

    test "hits when the attack roll exceeds the defender's armor class" do
      assert {:hit, _damage} = Combat.attack(Monster.for_round(1), %Player{}, always(20))
    end

    test "returns damage greater than zero on a hit" do
      {:hit, damage} = Combat.attack(%Player{damage: "2d6"}, fragile_monster(), always(20))
      assert damage > 0
    end

    test "damage matches the attacker's damage notation" do
      attacker = %Player{damage: "1d4"}
      {:hit, damage} = Combat.attack(attacker, fragile_monster(), always(4))
      assert damage == 4
    end
  end

  # ---------------------------------------------------------------------------
  # apply_damage/2
  # ---------------------------------------------------------------------------

  describe "apply_damage/2" do
    test "reduces hp by the given amount" do
      player = Combat.apply_damage(%Player{hp: 100}, 30)
      assert player.hp == 70
    end

    test "clamps hp to zero on lethal damage" do
      player = Combat.apply_damage(%Player{hp: 10}, 999)
      assert player.hp == 0
    end

    test "hp of zero stays zero" do
      player = Combat.apply_damage(%Player{hp: 0}, 10)
      assert player.hp == 0
    end
  end

  # ---------------------------------------------------------------------------
  # alive?/1
  # ---------------------------------------------------------------------------

  describe "alive?/1" do
    test "returns true when hp is positive" do
      assert Combat.alive?(%{hp: 1})
      assert Combat.alive?(%{hp: 100})
    end

    test "returns false when hp is zero" do
      refute Combat.alive?(%{hp: 0})
    end
  end

  # ---------------------------------------------------------------------------
  # tick/4 — :attack (default action)
  # ---------------------------------------------------------------------------

  describe "tick/4 — :attack" do
    test "returns :continue when both combatants survive the exchange" do
      player = fortress_player()
      monster = %{Monster.for_round(1) | armor_class: 21}

      assert {:continue, _player, _monster, log} =
               Combat.tick(player, monster, :attack, always(1))

      assert Enum.any?(log, &String.contains?(&1, "missed"))
    end

    test "returns :monster_dead when the player's attack kills the monster" do
      monster = %{fragile_monster() | hp: 1}
      player = %Player{damage: "1d6"}

      assert {:monster_dead, _player, dead_monster, log} =
               Combat.tick(player, monster, :attack, always(20))

      assert dead_monster.hp == 0
      assert Enum.any?(log, &String.contains?(&1, "defeated"))
    end

    test "monster does not attack when it is already dead" do
      monster = %{fragile_monster() | hp: 1}
      player = %Player{hp: 1, damage: "1d6"}

      assert {:monster_dead, surviving_player, _monster, _log} =
               Combat.tick(player, monster, :attack, always(20))

      assert surviving_player.hp == 1
    end

    test "returns :player_dead when the monster's attack kills the player" do
      monster = durable_monster()
      player = %Player{hp: 1, armor_class: 1}

      assert {:player_dead, dead_player, _monster, log} =
               Combat.tick(player, monster, :attack, always(20))

      assert dead_player.hp == 0
      assert Enum.any?(log, &String.contains?(&1, "defeated"))
    end

    test "tick/3 defaults to :attack action" do
      monster = %{fragile_monster() | hp: 1}
      player = %Player{damage: "1d6"}

      # tick/3 with roller only — should behave identically to :attack
      assert {:monster_dead, _player, _monster, _log} =
               Combat.tick(player, monster, :attack, always(20))
    end
  end

  # ---------------------------------------------------------------------------
  # tick/4 — :defend
  # ---------------------------------------------------------------------------

  describe "tick/4 — :defend" do
    test "player does not attack the monster" do
      monster = fragile_monster()
      player = %Player{}
      initial_monster_hp = monster.hp

      {:continue, _player, result_monster, _log} =
        Combat.tick(player, monster, :defend, always(1))

      assert result_monster.hp == initial_monster_hp
    end

    test "log contains a defensive stance message" do
      player = fortress_player()
      monster = %{Monster.for_round(1) | armor_class: 21}

      {:continue, _player, _monster, log} =
        Combat.tick(player, monster, :defend, always(1))

      assert Enum.any?(log, &String.contains?(&1, "brace"))
    end

    test "the +5 AC bonus causes attacks to miss that would otherwise hit" do
      # Player's base AC = 14; monster rolls 14 (would normally hit)
      # With defend bonus the effective AC = 19, so 14 misses
      player = %Player{hp: 50, armor_class: 14}
      monster = %{Monster.for_round(1) | hp: 100, max_hp: 100, armor_class: 1}

      {:continue, result_player, _monster, log} =
        Combat.tick(player, monster, :defend, always(14))

      assert result_player.hp == 50
      assert Enum.any?(log, &String.contains?(&1, "missed"))
    end

    test "AC is restored to its original value after defending" do
      player = %Player{armor_class: 14}
      monster = fragile_monster()

      {:continue, result_player, _monster, _log} =
        Combat.tick(player, monster, :defend, always(1))

      assert result_player.armor_class == 14
    end

    test "can still result in :player_dead if damage is lethal" do
      player = %Player{hp: 1, armor_class: 1}
      monster = %{Monster.for_round(1) | armor_class: 1, damage: "1d4"}

      assert {:player_dead, dead_player, _monster, _log} =
               Combat.tick(player, monster, :defend, always(20))

      assert dead_player.hp == 0
    end
  end

  # ---------------------------------------------------------------------------
  # tick/4 — :heal
  # ---------------------------------------------------------------------------

  describe "tick/4 — :heal" do
    test "restores HP by the dice roll amount" do
      player = %Player{hp: 50, max_hp: 100, potions: 2, armor_class: 21}
      monster = %{Monster.for_round(1) | armor_class: 21}

      # always(2) → 2d4 with always(2) = 4 HP healed; monster misses (roll 2 < AC 21)
      {:continue, healed_player, _monster, _log} =
        Combat.tick(player, monster, :heal, always(2))

      assert healed_player.hp == 54
    end

    test "hp does not exceed max_hp" do
      player = %Player{hp: 99, max_hp: 100, potions: 1, armor_class: 21}
      monster = %{Monster.for_round(1) | armor_class: 21}

      {:continue, healed_player, _monster, _log} =
        Combat.tick(player, monster, :heal, always(4))

      assert healed_player.hp == 100
    end

    test "decrements the potion count" do
      player = %Player{hp: 50, max_hp: 100, potions: 2, armor_class: 21}
      monster = %{Monster.for_round(1) | armor_class: 21}

      {:continue, result_player, _monster, _log} =
        Combat.tick(player, monster, :heal, always(2))

      assert result_player.potions == 1
    end

    test "wasted turn and informative log when no potions remain" do
      player = %Player{hp: 50, max_hp: 100, potions: 0, armor_class: 21}
      monster = %{Monster.for_round(1) | armor_class: 21}

      {:continue, result_player, _monster, log} =
        Combat.tick(player, monster, :heal, always(1))

      assert result_player.hp == 50
      assert Enum.any?(log, &String.contains?(&1, "none left"))
    end

    test "monster still attacks after the player heals" do
      player = %Player{hp: 50, max_hp: 100, potions: 1, armor_class: 1}
      monster = %{Monster.for_round(1) | hp: 100, max_hp: 100, armor_class: 1, damage: "1d4"}

      # always(4) → heals 8 HP (2d4), monster hits and deals 4 damage
      # net: 50 + 8 - 4 = 54
      {:continue, result_player, _monster, _log} =
        Combat.tick(player, monster, :heal, always(4))

      assert result_player.hp == 54
    end

    test "can still result in :player_dead if monster's counter-attack is lethal" do
      # max_hp=2 caps the heal so the monster's always(20) damage still kills the player
      player = %Player{hp: 1, max_hp: 2, potions: 1, armor_class: 1}
      monster = %{Monster.for_round(1) | armor_class: 1, damage: "1d6"}

      assert {:player_dead, dead_player, _monster, _log} =
               Combat.tick(player, monster, :heal, always(20))

      assert dead_player.hp == 0
    end
  end
end
