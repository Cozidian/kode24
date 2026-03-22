defmodule DungeonGame.LootTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Item, Loot}

  defp always(n), do: fn _sides -> n end

  describe "roll/2 (normal fight — gold only)" do
    test "returns gold when roll hits" do
      monster = %{gold: 5}
      result = Loot.roll(monster, always(2))
      assert result == [{:gold, 5}]
    end

    test "returns empty list when roll misses" do
      monster = %{gold: 5}
      assert Loot.roll(monster, always(1)) == []
    end

    test "never returns items or potions" do
      monster = %{gold: 10}
      result = Loot.roll(monster, always(2))
      refute Enum.any?(result, fn {type, _} -> type in [:item, :potion] end)
    end
  end

  describe "elite_choices/1" do
    test "returns exactly 3 choices" do
      choices = Loot.elite_choices(always(1))
      assert length(choices) == 3
    end

    test "all choices are {:item, %Item{}} or {:potion, n}" do
      choices = Loot.elite_choices(always(1))

      Enum.each(choices, fn choice ->
        assert match?({:item, %Item{}}, choice) or match?({:potion, _}, choice)
      end)
    end

    test "includes at least one potion choice" do
      choices = Loot.elite_choices(always(1))
      assert Enum.any?(choices, &match?({:potion, _}, &1))
    end

    test "includes at least one item choice" do
      choices = Loot.elite_choices(always(1))
      assert Enum.any?(choices, &match?({:item, _}, &1))
    end
  end
end
