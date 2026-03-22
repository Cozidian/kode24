defmodule DungeonGame.PlayerClassTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Card, Player, PlayerClass}

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

    test "starts with 60 HP", %{player: p} do
      assert p.hp == 60
      assert p.max_hp == 60
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

    test "starts with 5 cards in hand", %{player: p} do
      assert length(p.hand) == 5
    end

    test "starts with 5 cards remaining in deck", %{player: p} do
      assert length(p.deck) == 5
    end

    test "starts with 3 energy", %{player: p} do
      assert p.energy == 3
      assert p.max_energy == 3
    end

    test "starts with 0 block", %{player: p} do
      assert p.block == 0
    end

    test "hand cards are from warrior deck", %{player: p} do
      warrior_ids = Card.starting_deck(:warrior) |> Enum.map(& &1.id) |> MapSet.new()
      for card <- p.hand, do: assert(card.id in warrior_ids)
    end
  end

  describe "new_player/2 — rogue" do
    setup do
      %{player: PlayerClass.new_player(:rogue, "Shadow")}
    end

    test "sets class to :rogue", %{player: p} do
      assert p.class == :rogue
    end

    test "starts with 45 HP", %{player: p} do
      assert p.hp == 45
      assert p.max_hp == 45
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

    test "starts with 5 cards in hand", %{player: p} do
      assert length(p.hand) == 5
    end
  end

  describe "new_player/2 — mage" do
    setup do
      %{player: PlayerClass.new_player(:mage, "Gandalf")}
    end

    test "sets class to :mage", %{player: p} do
      assert p.class == :mage
    end

    test "starts with 30 HP", %{player: p} do
      assert p.hp == 30
      assert p.max_hp == 30
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

    test "starts with 5 cards in hand", %{player: p} do
      assert length(p.hand) == 5
    end

    test "hand cards are from mage deck", %{player: p} do
      mage_ids = Card.starting_deck(:mage) |> Enum.map(& &1.id) |> MapSet.new()
      for card <- p.hand, do: assert(card.id in mage_ids)
    end
  end

  describe "default Player struct" do
    test "potions default is 0" do
      assert %Player{}.potions == 0
    end

    test "hand default is empty list" do
      assert %Player{}.hand == []
    end

    test "energy default is 0" do
      assert %Player{}.energy == 0
    end

    test "block default is 0" do
      assert %Player{}.block == 0
    end
  end
end
