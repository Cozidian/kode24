defmodule DungeonGame.InventoryTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Item, Player}

  describe "Player.unequip/2" do
    test "unequipping a weapon returns it to inventory and clears the slot" do
      weapon = %Item{type: :weapon, name: "Sword +2", bonus: 2}
      player = %Player{equipped_weapon: weapon, bonus_damage: 2}

      result = Player.unequip(player, :weapon)

      assert result.equipped_weapon == nil
      assert result.bonus_damage == 0
      assert weapon in result.inventory
    end

    test "unequipping armor returns it to inventory and resets bonus_ac" do
      armor = %Item{type: :armor, name: "Chain Mail +2", bonus: 2}
      player = %Player{equipped_armor: armor, bonus_ac: 2}

      result = Player.unequip(player, :armor)

      assert result.equipped_armor == nil
      assert result.bonus_ac == 0
      assert armor in result.inventory
    end
  end

  describe "Player.equip/2" do
    test "equipping a weapon sets equipped_weapon and bonus_damage" do
      weapon = %Item{type: :weapon, name: "Sword +2", bonus: 2}
      player = %Player{}

      result = Player.equip(player, weapon)

      assert result.equipped_weapon == weapon
      assert result.bonus_damage == 2
    end

    test "equipping armor sets equipped_armor and bonus_ac" do
      armor = %Item{type: :armor, name: "Chain Mail +1", bonus: 1}
      player = %Player{}

      result = Player.equip(player, armor)

      assert result.equipped_armor == armor
      assert result.bonus_ac == 1
    end

    test "equipping a second weapon moves the first to inventory" do
      old_weapon = %Item{type: :weapon, name: "Dagger +1", bonus: 1}
      new_weapon = %Item{type: :weapon, name: "Sword +3", bonus: 3}
      player = %Player{equipped_weapon: old_weapon, bonus_damage: 1}

      result = Player.equip(player, new_weapon)

      assert result.equipped_weapon == new_weapon
      assert result.bonus_damage == 3
      assert old_weapon in result.inventory
    end
  end
end
