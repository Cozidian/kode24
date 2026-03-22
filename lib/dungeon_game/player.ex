defmodule DungeonGame.Player do
  @moduledoc "Represents the player character."

  alias DungeonGame.{Item}

  defstruct name: "Hero",
            hp: 20,
            max_hp: 20,
            damage: "1d4",
            armor_class: 14,
            potions: 0,
            gold: 0,
            inventory: [],
            equipped_weapon: nil,
            equipped_helm: nil,
            equipped_body: nil,
            equipped_boots: nil,
            bonus_damage: 0,
            bonus_ac: 0,
            class: nil,
            hand: [],
            deck: [],
            discard: [],
            energy: 0,
            max_energy: 3,
            block: 0,
            dodge_next: false

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
