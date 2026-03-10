defmodule DungeonGame.InventoryTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Item, Player}

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
