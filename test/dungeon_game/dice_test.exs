defmodule DungeonGame.DiceTest do
  use ExUnit.Case, async: true

  alias DungeonGame.Dice

  # Roller helpers that produce deterministic results
  defp always(n), do: fn _sides -> n end

  describe "roll/2" do
    test "returns a value within the valid range using the default random roller" do
      result = Dice.roll("1d6")
      assert result in 1..6
    end

    test "sums multiple dice correctly" do
      # 3d4 with max roller → 4+4+4 = 12
      assert Dice.roll("3d4", always(4)) == 12
    end

    test "returns maximum possible result when roller always returns max" do
      assert Dice.roll("2d6", fn sides -> sides end) == 12
      assert Dice.roll("1d20", fn sides -> sides end) == 20
    end

    test "returns minimum possible result when roller always returns 1" do
      assert Dice.roll("2d6", always(1)) == 2
      assert Dice.roll("4d4", always(1)) == 4
    end

    test "rolls the correct number of dice" do
      # With a roller that returns 3, 1d6 gives 3 and 4d6 gives 12
      assert Dice.roll("1d6", always(3)) == 3
      assert Dice.roll("4d6", always(3)) == 12
    end
  end
end
