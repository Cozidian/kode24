defmodule DungeonGame.LootTest do
  use ExUnit.Case, async: true

  alias DungeonGame.Loot

  defp always(n), do: fn _sides -> n end

  describe "roll/2" do
    # always(2): gold roll 2 == 2 → drops; item roll 2 == 2 → drops
    test "returns a list with gold and an item when both drop" do
      monster = %{gold: 5}

      result = Loot.roll(monster, always(2))

      assert {:gold, 5} in result
      assert Enum.any?(result, fn {:item, _} -> true; _ -> false end)
    end

    # always(1): gold roll 1 != 2 → no drop; item roll 1 != 2 → no drop
    test "returns an empty list when nothing drops" do
      monster = %{gold: 5}

      assert Loot.roll(monster, always(1)) == []
    end
  end
end
