defmodule DungeonGame.Player do
  @moduledoc "Represents the player character."

  alias DungeonGame.{Dice, Item}

  defstruct name: "Hero",
            hp: 20,
            max_hp: 20,
            damage: "1d4",
            armor_class: 14,
            potions: 0,
            xp: 0,
            level: 1,
            gold: 0,
            inventory: [],
            equipped_weapon: nil,
            equipped_helm: nil,
            equipped_body: nil,
            equipped_boots: nil,
            bonus_damage: 0,
            bonus_ac: 0,
            defending: false,
            upgrade_attack: nil,
            upgrade_defend: nil,
            upgrade_heal: nil,
            upgrades_passive: [],
            class: nil,
            shield_charges: 0,
            combo: 0,
            mana: 0,
            max_mana: 0,
            frost_nova_active: false

  @doc """
  Returns the minimum XP required to reach `level`.

  Thresholds are cumulative: level 2 at 10 XP, level 3 at 30, level 4 at 70, level 5 at 150, …
  Each gap doubles: 10, 20, 40, 80, …
  Formula: threshold(n) = 10 * (2^(n-1) - 1)
  """
  @spec xp_threshold(pos_integer()) :: non_neg_integer()
  def xp_threshold(level), do: trunc(10 * (:math.pow(2, level - 1) - 1))

  @doc """
  Returns the level a player should be at for a given total XP.
  """
  @spec level_for_xp(non_neg_integer()) :: pos_integer()
  def level_for_xp(xp) do
    Enum.reduce_while(2..100, 1, fn candidate, current ->
      if xp >= xp_threshold(candidate), do: {:cont, candidate}, else: {:halt, current}
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
          max_hp: player.max_hp + bonus,
          hp: player.max_hp + bonus,
          damage: damage
      }
    else
      player
    end
  end

  @doc """
  Equips an item into the appropriate slot, displacing the previous item (if any) into inventory.
  `bonus_ac` is always recalculated from the sum of all three armor slot bonuses.

  - `:weapon` → `equipped_weapon`, updates `bonus_damage`
  - `:helm`   → `equipped_helm`, updates `bonus_ac`
  - `:armor`  → `equipped_body`, updates `bonus_ac`
  - `:boots`  → `equipped_boots`, updates `bonus_ac`
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

  def equip(player, %Item{type: type} = item) when type in [:helm, :armor, :boots] do
    field = armor_field(type)
    old = Map.get(player, field)
    player = struct!(player, [{field, item}, {:inventory, List.wrap(old) ++ player.inventory}])
    %{player | bonus_ac: calc_bonus_ac(player)}
  end

  @doc """
  Unequips the item in the given slot, returning it to inventory and recalculating `bonus_ac`.

  - `:weapon` → clears `equipped_weapon`, resets `bonus_damage` to 0
  - `:helm`   → clears `equipped_helm`, updates `bonus_ac`
  - `:body`   → clears `equipped_body`, updates `bonus_ac`
  - `:boots`  → clears `equipped_boots`, updates `bonus_ac`
  """
  @spec unequip(%__MODULE__{}, :weapon | :helm | :body | :boots) :: %__MODULE__{}
  def unequip(player, :weapon) do
    %{
      player
      | equipped_weapon: nil,
        bonus_damage: 0,
        inventory: List.wrap(player.equipped_weapon) ++ player.inventory
    }
  end

  def unequip(player, slot) when slot in [:helm, :body, :boots] do
    field = armor_field(slot)
    old = Map.get(player, field)
    player = struct!(player, [{field, nil}, {:inventory, List.wrap(old) ++ player.inventory}])
    %{player | bonus_ac: calc_bonus_ac(player)}
  end

  defp calc_bonus_ac(player) do
    slot_bonus(player.equipped_helm) + slot_bonus(player.equipped_body) +
      slot_bonus(player.equipped_boots)
  end

  defp slot_bonus(nil), do: 0
  defp slot_bonus(%Item{bonus: b}), do: b

  # Maps item type or unequip slot atom to the corresponding struct field.
  # :armor (item type) and :body (unequip slot) both refer to equipped_body.
  defp armor_field(:helm), do: :equipped_helm
  defp armor_field(:armor), do: :equipped_body
  defp armor_field(:body), do: :equipped_body
  defp armor_field(:boots), do: :equipped_boots
end
