defmodule DungeonGame.PlayerTest do
  use ExUnit.Case, async: true

  alias DungeonGame.Player

  # Roller helper — returns n for any die size
  defp always(n), do: fn _sides -> n end

  describe "apply_level_up/2 — damage scaling" do
    test "damage becomes 1d6 when reaching level 3" do
      player = %Player{xp: 30, level: 2, damage: "1d4"}

      leveled = Player.apply_level_up(player, always(1))

      assert leveled.damage == "1d6"
    end

    test "damage becomes 2d6 when reaching level 5" do
      player = %Player{xp: 150, level: 4, damage: "1d6"}

      leveled = Player.apply_level_up(player, always(1))

      assert leveled.damage == "2d6"
    end

    test "damage is unchanged at levels without a damage upgrade" do
      level2_player = %Player{xp: 10, level: 1, damage: "1d4"}
      level4_player = %Player{xp: 70, level: 3, damage: "1d6"}

      assert Player.apply_level_up(level2_player, always(1)).damage == "1d4"
      assert Player.apply_level_up(level4_player, always(1)).damage == "1d6"
    end
  end

  describe "level_for_xp/1" do
    test "returns level 1 before reaching first threshold" do
      assert Player.level_for_xp(0) == 1
      assert Player.level_for_xp(9) == 1
    end

    test "returns level 2 at 10 XP and level 3 at 30 XP" do
      assert Player.level_for_xp(10) == 2
      assert Player.level_for_xp(29) == 2
      assert Player.level_for_xp(30) == 3
    end

    test "each subsequent threshold doubles: 10, 30, 70, 150" do
      assert Player.level_for_xp(70) == 4
      assert Player.level_for_xp(150) == 5
    end
  end
end
