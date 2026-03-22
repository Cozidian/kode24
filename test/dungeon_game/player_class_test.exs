defmodule DungeonGame.PlayerClassTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Player, PlayerClass}

  describe "all/0" do
    test "returns exactly 3 classes" do
      assert length(PlayerClass.all()) == 3
    end

    test "includes warrior, rogue, and mage" do
      ids = PlayerClass.all() |> Enum.map(& &1.id)
      assert :warrior in ids
      assert :rogue in ids
      assert :mage in ids
    end
  end

  describe "new_player/2 — warrior" do
    setup do
      %{player: PlayerClass.new_player(:warrior, "Thor")}
    end

    test "sets name", %{player: p} do
      assert p.name == "Thor"
    end

    test "sets class to :warrior", %{player: p} do
      assert p.class == :warrior
    end

    test "starts with 12 HP", %{player: p} do
      assert p.hp == 12
      assert p.max_hp == 12
    end

    test "starts with AC 16", %{player: p} do
      assert p.armor_class == 16
    end

    test "starts with 1d8 damage", %{player: p} do
      assert p.damage == "1d8"
    end

    test "starts with 0 potions", %{player: p} do
      assert p.potions == 0
    end

    test "starts with 0 shield charges", %{player: p} do
      assert p.shield_charges == 0
    end

    test "starts with 0 mana", %{player: p} do
      assert p.mana == 0
      assert p.max_mana == 0
    end
  end

  describe "new_player/2 — rogue" do
    setup do
      %{player: PlayerClass.new_player(:rogue, "Shadow")}
    end

    test "sets class to :rogue", %{player: p} do
      assert p.class == :rogue
    end

    test "starts with 8 HP", %{player: p} do
      assert p.hp == 8
      assert p.max_hp == 8
    end

    test "starts with AC 13", %{player: p} do
      assert p.armor_class == 13
    end

    test "starts with 1d6 damage", %{player: p} do
      assert p.damage == "1d6"
    end

    test "starts with 0 potions", %{player: p} do
      assert p.potions == 0
    end

    test "starts with 0 combo", %{player: p} do
      assert p.combo == 0
    end
  end

  describe "new_player/2 — mage" do
    setup do
      %{player: PlayerClass.new_player(:mage, "Gandalf")}
    end

    test "sets class to :mage", %{player: p} do
      assert p.class == :mage
    end

    test "starts with 6 HP", %{player: p} do
      assert p.hp == 6
      assert p.max_hp == 6
    end

    test "starts with AC 11", %{player: p} do
      assert p.armor_class == 11
    end

    test "starts with 1d4 damage", %{player: p} do
      assert p.damage == "1d4"
    end

    test "starts with 0 potions", %{player: p} do
      assert p.potions == 0
    end

    test "starts with 3/3 mana", %{player: p} do
      assert p.mana == 3
      assert p.max_mana == 3
    end
  end

  describe "default Player struct" do
    test "potions default is 0" do
      assert %Player{}.potions == 0
    end
  end
end
