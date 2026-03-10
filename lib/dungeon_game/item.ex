defmodule DungeonGame.Item do
  @moduledoc """
  Represents a piece of loot the player can pick up and equip.

  Types:
    - `:weapon` — adds `bonus` to damage rolls
    - `:armor`  — adds `bonus` to armor class
    - `:helm`   — adds `bonus` to armor class (same slot as armor)
  """

  defstruct [:type, :name, :bonus]

  @doc """
  Generates a random item using the injectable `roller`.

  - `roller.(3)` selects the item type (1=weapon, 2=armor, 3=helm)
  - `roller.(3)` selects the bonus tier (1=+1, 2=+2, 3=+3)
  """
  @spec random(DungeonGame.Dice.roller()) :: %__MODULE__{}
  def random(roller) do
    types = [:weapon, :armor, :helm]
    type = Enum.at(types, roller.(3) - 1)
    Enum.at(pool()[type], roller.(3) - 1)
  end

  defp pool do
    %{
      weapon: [
        %__MODULE__{type: :weapon, name: "Dagger", bonus: 1},
        %__MODULE__{type: :weapon, name: "Short Sword", bonus: 2},
        %__MODULE__{type: :weapon, name: "Long Sword", bonus: 3}
      ],
      armor: [
        %__MODULE__{type: :armor, name: "Leather Armor", bonus: 1},
        %__MODULE__{type: :armor, name: "Chain Mail", bonus: 2},
        %__MODULE__{type: :armor, name: "Plate Mail", bonus: 3}
      ],
      helm: [
        %__MODULE__{type: :helm, name: "Iron Helm", bonus: 1},
        %__MODULE__{type: :helm, name: "Steel Helm", bonus: 2},
        %__MODULE__{type: :helm, name: "Dragon Helm", bonus: 3}
      ]
    }
  end
end
