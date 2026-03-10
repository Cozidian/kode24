defmodule DungeonGame.UpgradeTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Combat, Monster, Player, Upgrade}

  defp always(n), do: fn _sides -> n end

  defp attack_only(monster),
    do: %{monster | actions: [%{name: "Attack", type: :attack, weight: 1}], next_action: nil}

  defp fragile_monster, do: attack_only(%{Monster.for_round(1) | armor_class: 1})

  # ---------------------------------------------------------------------------
  # Upgrade.all/0
  # ---------------------------------------------------------------------------

  describe "Upgrade.all/0" do
    test "includes at least one upgrade for each type: attack, defend, heal, passive" do
      all = Upgrade.all()
      assert Enum.any?(all, &(&1.type == :attack))
      assert Enum.any?(all, &(&1.type == :defend))
      assert Enum.any?(all, &(&1.type == :heal))
      assert Enum.any?(all, &(&1.type == :passive))
    end
  end

  # ---------------------------------------------------------------------------
  # Upgrade.random_choices/2
  # ---------------------------------------------------------------------------

  describe "Upgrade.random_choices/2" do
    test "excludes the player's currently equipped action upgrade from the offered choices" do
      double_strike = Enum.find(Upgrade.all(), &(&1.id == :double_strike))
      player = %Player{upgrade_attack: double_strike}

      # Ask for as many choices as possible — double_strike must never appear
      choices = Upgrade.random_choices(player, length(Upgrade.all()))

      refute Enum.any?(choices, &(&1.id == :double_strike))
    end
  end

  # ---------------------------------------------------------------------------
  # Upgrade.apply/2
  # ---------------------------------------------------------------------------

  describe "Upgrade.apply/2" do
    test "equipping an attack upgrade stores it in the attack slot" do
      double_strike = Enum.find(Upgrade.all(), &(&1.id == :double_strike))
      player = Upgrade.apply(%Player{}, double_strike)
      assert player.upgrade_attack.id == :double_strike
    end

    test "equipping a second attack upgrade replaces the first" do
      [first, second | _] = Enum.filter(Upgrade.all(), &(&1.type == :attack))
      player = %Player{} |> Upgrade.apply(first) |> Upgrade.apply(second)
      assert player.upgrade_attack.id == second.id
    end

    test "equipping a passive upgrade appends it to the upgrades_passive list" do
      tough = Enum.find(Upgrade.all(), &(&1.id == :tough))
      player = Upgrade.apply(%Player{}, tough)
      assert Enum.any?(player.upgrades_passive, &(&1.id == :tough))
    end
  end

  # ---------------------------------------------------------------------------
  # Combat effects
  # ---------------------------------------------------------------------------

  describe "double_strike — combat effect" do
    test "player with double_strike kills a monster that would survive a single hit" do
      double_strike = Enum.find(Upgrade.all(), &(&1.id == :double_strike))
      # Monster has 5 HP: survives one 1d4=3 hit, but not two
      monster = %{fragile_monster() | hp: 5, xp: 0}
      player = %Player{damage: "1d4", upgrade_attack: double_strike}

      # always(3): each attack deals 3; first hit 5→2 HP, second hit 2→0 HP → dead
      assert {:monster_dead, _player, _monster, _log} =
               Combat.tick(player, monster, :attack, always(3))
    end
  end

  describe "empower — combat effect" do
    test "player with empower heals more from a potion than the standard 2d4" do
      empower = Enum.find(Upgrade.all(), &(&1.id == :empower))
      # AC 21 ensures the monster's counter-attack misses on always(1)
      player = %Player{hp: 50, max_hp: 100, potions: 1, armor_class: 21, upgrade_heal: empower}
      monster = attack_only(Monster.for_round(1))

      # always(1): empower → 4d4 = 1+1+1+1=4 healed; standard would be 2d4 = 1+1=2
      {:continue, healed_player, _monster, _log} =
        Combat.tick(player, monster, :heal, always(1))

      assert healed_player.hp == 54
    end
  end
end
