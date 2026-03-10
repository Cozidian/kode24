defmodule DungeonGame.MonsterTest do
  use ExUnit.Case, async: true

  alias DungeonGame.Monster

  describe "for_round/1" do
    test "spawns a Goblin for rounds 1–3" do
      assert Monster.for_round(1).name == "Goblin"
      assert Monster.for_round(3).name == "Goblin"
    end

    test "spawns an Orc for rounds 4–6" do
      assert Monster.for_round(4).name == "Orc"
      assert Monster.for_round(6).name == "Orc"
    end

    test "spawns a Troll for rounds 7–9" do
      assert Monster.for_round(7).name == "Troll"
      assert Monster.for_round(9).name == "Troll"
    end

    test "spawns a Dragon from round 10 onwards" do
      assert Monster.for_round(10).name == "Dragon"
      assert Monster.for_round(99).name == "Dragon"
    end

    test "hp is higher for later rounds" do
      assert Monster.for_round(5).hp > Monster.for_round(1).hp
      assert Monster.for_round(10).hp > Monster.for_round(5).hp
    end

    test "hp and max_hp are equal at spawn" do
      monster = Monster.for_round(1)
      assert monster.hp == monster.max_hp
    end

    test "hp is positive for all rounds" do
      for round <- 1..20 do
        assert Monster.for_round(round).hp > 0
      end
    end
  end

  describe "xp" do
    test "each monster type has a positive xp value" do
      # Goblin
      assert Monster.for_round(1).xp > 0
      # Orc
      assert Monster.for_round(4).xp > 0
      # Troll
      assert Monster.for_round(7).xp > 0
      # Dragon
      assert Monster.for_round(10).xp > 0
    end

    test "xp increases with monster tier: Goblin < Orc < Troll < Dragon" do
      goblin_xp = Monster.for_round(1).xp
      orc_xp = Monster.for_round(4).xp
      troll_xp = Monster.for_round(7).xp
      dragon_xp = Monster.for_round(10).xp

      assert goblin_xp < orc_xp
      assert orc_xp < troll_xp
      assert troll_xp < dragon_xp
    end
  end
end
