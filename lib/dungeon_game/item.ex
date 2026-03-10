defmodule DungeonGame.Item do
  @moduledoc """
  Represents a piece of loot the player can pick up and equip.

  Types:
    - `:weapon` — adds `bonus` to damage rolls
    - `:armor`  — body armour slot, adds `bonus` to armor class
    - `:helm`   — helm slot, adds `bonus` to armor class
    - `:boots`  — boots slot, adds `bonus` to armor class
  """

  defstruct [:type, :name, :bonus]

  @doc """
  Generates a random item using the injectable `roller`.

  - `roller.(4)` selects the item type (1=weapon, 2=armor, 3=helm, 4=boots)
  - `roller.(3)` selects the bonus tier (1=+1, 2=+2, 3=+3)
  """
  @spec random(DungeonGame.Dice.roller()) :: %__MODULE__{}
  def random(roller) do
    types = [:weapon, :armor, :helm, :boots]
    type = Enum.at(types, roller.(4) - 1)
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
      ],
      boots: [
        %__MODULE__{type: :boots, name: "Leather Boots", bonus: 1},
        %__MODULE__{type: :boots, name: "Iron Boots", bonus: 2},
        %__MODULE__{type: :boots, name: "Dragon Boots", bonus: 3}
      ]
    }
  end
end
