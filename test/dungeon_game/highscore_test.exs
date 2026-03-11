defmodule DungeonGame.HighscoreTest do
  use ExUnit.Case, async: false

  setup do
    DungeonGame.Highscore.clear()
    :ok
  end

  test "list/0 returns an empty list when no scores have been added" do
    assert DungeonGame.Highscore.list() == []
  end

  test "add/2 stores entries and list/0 returns them sorted by rounds descending" do
    DungeonGame.Highscore.add("Alice", 5)
    DungeonGame.Highscore.add("Bob", 3)
    DungeonGame.Highscore.add("Charlie", 8)

    assert [
             %{name: "Charlie", rounds: 8},
             %{name: "Alice", rounds: 5},
             %{name: "Bob", rounds: 3}
           ] = DungeonGame.Highscore.list()
  end

  test "list/0 keeps only the top 10 entries when more than 10 scores are added" do
    for i <- 1..12 do
      DungeonGame.Highscore.add("Player #{i}", i)
    end

    entries = DungeonGame.Highscore.list()
    assert length(entries) == 10
    assert hd(entries).rounds == 12
    assert List.last(entries).rounds == 3
  end
end
