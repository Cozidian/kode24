defmodule DungeonGame.Player do
  @moduledoc "Represents the player character."

  alias DungeonGame.{Dice, Item}

  defstruct name: "Hero",
            hp: 20,
            max_hp: 20,
            damage: "1d4",
            armor_class: 14,
            potions: 2,
            xp: 0,
            level: 1,
            gold: 0,
            inventory: [],
            equipped_weapon: nil,
            equipped_armor: nil,
            bonus_damage: 0,
            bonus_ac: 0

  @doc """
  Returns the level a player should be at for a given total XP.

  Thresholds are cumulative: level 2 at 10 XP, level 3 at 30, level 4 at 70, level 5 at 150, …
  Each gap doubles: 10, 20, 40, 80, …
  Formula: threshold(n) = 10 * (2^(n-1) - 1)
  """
  @spec level_for_xp(non_neg_integer()) :: pos_integer()
  def level_for_xp(xp) do
    Enum.reduce_while(2..100, 1, fn candidate, current ->
      threshold = trunc(10 * (:math.pow(2, candidate - 1) - 1))
      if xp >= threshold, do: {:cont, candidate}, else: {:halt, current}
    end)
  end

  @doc """
  Checks whether the player's current XP warrants a higher level than `player.level`.
  If so, increments level and adds `new_level * d6` to both `hp` and `max_hp`.
  Returns the updated player (unchanged if no level-up occurred).
  """
  @damage_upgrades %{3 => "1d6", 5 => "2d6"}

  @spec apply_level_up(%__MODULE__{}, Dice.roller()) :: %__MODULE__{}
  def apply_level_up(player, roller) do
    new_level = level_for_xp(player.xp)

    if new_level > player.level do
      bonus = Dice.roll("#{new_level}d6", roller)
      damage = Map.get(@damage_upgrades, new_level, player.damage)

      %{
        player
        | level: new_level,
          hp: player.hp + bonus,
          max_hp: player.max_hp + bonus,
          damage: damage
      }
    else
      player
    end
  end

  @doc """
  Equips an item, placing the previously equipped item of the same slot into inventory.

  - `:weapon` → sets `equipped_weapon` and `bonus_damage`
  - `:armor` / `:helm` → sets `equipped_armor` and `bonus_ac`
  """
  @spec equip(%__MODULE__{}, %Item{}) :: %__MODULE__{}
  def equip(player, %Item{type: :weapon} = item) do
    %{
      player
      | equipped_weapon: item,
        bonus_damage: item.bonus,
        inventory: List.wrap(player.equipped_weapon) ++ player.inventory
    }
  end

  def equip(player, %Item{type: type} = item) when type in [:armor, :helm] do
    %{
      player
      | equipped_armor: item,
        bonus_ac: item.bonus,
        inventory: List.wrap(player.equipped_armor) ++ player.inventory
    }
  end

  @doc """
  Unequips the item in the given slot, returning it to inventory and resetting the bonus.

  - `:weapon` → clears `equipped_weapon`, resets `bonus_damage` to 0
  - `:armor`  → clears `equipped_armor`, resets `bonus_ac` to 0
  """
  @spec unequip(%__MODULE__{}, :weapon | :armor) :: %__MODULE__{}
  def unequip(player, :weapon) do
    %{
      player
      | equipped_weapon: nil,
        bonus_damage: 0,
        inventory: List.wrap(player.equipped_weapon) ++ player.inventory
    }
  end

  def unequip(player, :armor) do
    %{
      player
      | equipped_armor: nil,
        bonus_ac: 0,
        inventory: List.wrap(player.equipped_armor) ++ player.inventory
    }
  end
end
