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

    test "unequipping body armor returns it to inventory and resets bonus_ac" do
      armor = %Item{type: :armor, name: "Chain Mail +2", bonus: 2}
      player = %Player{equipped_body: armor, bonus_ac: 2}

      result = Player.unequip(player, :body)

      assert result.equipped_body == nil
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

    test "equipping body armor sets equipped_body and bonus_ac" do
      armor = %Item{type: :armor, name: "Chain Mail +1", bonus: 1}
      player = %Player{}

      result = Player.equip(player, armor)

      assert result.equipped_body == armor
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

  describe "three-slot armor system" do
    test "equipping a helm sets equipped_helm and adds its bonus to bonus_ac" do
      helm = %Item{type: :helm, name: "Iron Helm", bonus: 1}
      player = %Player{}

      result = Player.equip(player, helm)

      assert result.equipped_helm == helm
      assert result.bonus_ac == 1
    end

    test "equipping body armor sets equipped_body and adds its bonus to bonus_ac" do
      armor = %Item{type: :armor, name: "Chain Mail", bonus: 2}
      player = %Player{}

      result = Player.equip(player, armor)

      assert result.equipped_body == armor
      assert result.bonus_ac == 2
    end

    test "equipping boots sets equipped_boots and adds its bonus to bonus_ac" do
      boots = %Item{type: :boots, name: "Leather Boots", bonus: 1}
      player = %Player{}

      result = Player.equip(player, boots)

      assert result.equipped_boots == boots
      assert result.bonus_ac == 1
    end

    test "all three armor slots stack their bonuses in bonus_ac" do
      helm = %Item{type: :helm, name: "Iron Helm", bonus: 1}
      armor = %Item{type: :armor, name: "Chain Mail", bonus: 2}
      boots = %Item{type: :boots, name: "Leather Boots", bonus: 1}

      player =
        %Player{}
        |> Player.equip(helm)
        |> Player.equip(armor)
        |> Player.equip(boots)

      assert player.bonus_ac == 4
    end

    test "unequipping body armor removes only its bonus, leaving other slots intact" do
      helm = %Item{type: :helm, name: "Iron Helm", bonus: 1}
      armor = %Item{type: :armor, name: "Chain Mail", bonus: 2}

      player =
        %Player{}
        |> Player.equip(helm)
        |> Player.equip(armor)
        |> Player.unequip(:body)

      assert player.equipped_body == nil
      assert player.bonus_ac == 1
      assert armor in player.inventory
    end
  end
end
