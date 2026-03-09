defmodule DungeonGame.Dice do
  @moduledoc """
  Dice rolling with standard dice notation (e.g. "2d6", "1d20").

  The `roller` function is injectable for deterministic testing.
  It receives the number of sides and must return an integer between 1 and sides.

  ## Examples

      # Real random rolls
      DungeonGame.Dice.roll("2d6")

      # Deterministic rolls in tests
      always_max = fn sides -> sides end
      DungeonGame.Dice.roll("2d6", always_max)  #=> 12
  """

  @type roller :: (pos_integer() -> pos_integer())

  @doc """
  Rolls dice described by `notation` (e.g. "2d6", "1d20") using `roller`.
  Returns the sum of all dice rolls.
  """
  @spec roll(String.t(), roller()) :: pos_integer()
  def roll(notation, roller \\ &:rand.uniform/1) do
    {count, sides} = parse(notation)
    Enum.sum(for _ <- 1..count, do: roller.(sides))
  end

  @spec parse(String.t()) :: {pos_integer(), pos_integer()}
  defp parse(notation) do
    [count_str, sides_str] = String.split(notation, "d")
    {String.to_integer(count_str), String.to_integer(sides_str)}
  end
end
