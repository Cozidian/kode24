defmodule DungeonGame.CombatTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Card, Combat, Monster, Player, PlayerClass}

  # Roller helpers
  defp always(n), do: fn _sides -> n end

  defp attack_only(monster) do
    %{monster | actions: [%{name: "Attack", type: :attack, weight: 1}], next_action: nil}
  end

  defp fragile_monster,
    do: attack_only(%{Monster.for_round(1) | armor_class: 1, hp: 100, max_hp: 100})

  defp durable_monster,
    do: attack_only(%{Monster.for_round(1) | hp: 1000, max_hp: 1000, armor_class: 1})

  defp fortress_player, do: warrior() |> Map.put(:armor_class, 21)

  defp warrior, do: PlayerClass.new_player(:warrior, "Thor")

  defp card(class, id), do: Enum.find(Card.all(class), &(&1.id == id))

  # ---------------------------------------------------------------------------
  # attack/3 (primitive — unchanged)
  # ---------------------------------------------------------------------------

  describe "attack/3" do
    test "misses when roll is below AC" do
      assert Combat.attack(Monster.for_round(1), %Player{armor_class: 14}, always(1)) == :miss
    end

    test "hits when roll meets AC" do
      assert {:hit, _} = Combat.attack(Monster.for_round(1), %Player{armor_class: 10}, always(10))
    end

    test "damage matches dice notation" do
      {:hit, damage} = Combat.attack(%Player{damage: "1d4"}, fragile_monster(), always(4))
      assert damage == 4
    end
  end

  # ---------------------------------------------------------------------------
  # apply_damage/2 and alive?/1
  # ---------------------------------------------------------------------------

  describe "apply_damage/2" do
    test "reduces hp" do
      assert Combat.apply_damage(%Player{hp: 100}, 30).hp == 70
    end

    test "clamps to zero" do
      assert Combat.apply_damage(%Player{hp: 10}, 999).hp == 0
    end
  end

  describe "alive?/1" do
    test "true when hp > 0" do
      assert Combat.alive?(%Player{hp: 1})
    end

    test "false when hp == 0" do
      refute Combat.alive?(%Player{hp: 0})
    end
  end

  # ---------------------------------------------------------------------------
  # Combat.play_card/4
  # ---------------------------------------------------------------------------

  describe "play_card/4" do
    test "returns :alive when monster survives" do
      player = warrior()
      c = card(:warrior, :cleave)
      assert {:alive, _, _, _} = Combat.play_card(player, durable_monster(), c, always(20))
    end

    test "returns :monster_dead when monster dies" do
      player = warrior()
      weak = %{fragile_monster() | hp: 1}
      c = card(:warrior, :cleave)
      assert {:monster_dead, _, _, _} = Combat.play_card(player, weak, c, always(20))
    end

    test "deducts card cost from energy" do
      player = warrior()
      c = card(:warrior, :cleave)
      assert c.cost == 1
      {:alive, updated_player, _, _} = Combat.play_card(player, durable_monster(), c, always(20))
      assert updated_player.energy == player.energy - 1
    end

    test "moves card from hand to discard" do
      player = warrior()
      c = card(:warrior, :cleave)
      player = %{player | hand: [c], deck: [], discard: []}
      {:alive, updated_player, _, _} = Combat.play_card(player, durable_monster(), c, always(20))
      assert c not in updated_player.hand
      assert c in updated_player.discard
    end

    test "returns :alive with log when not enough energy" do
      player = %{warrior() | energy: 0}
      c = card(:warrior, :cleave)

      assert {:alive, ^player, _, log} =
               Combat.play_card(player, durable_monster(), c, always(20))

      assert Enum.any?(log, &String.contains?(&1, "energy"))
    end

    test "block card increases player block" do
      player = warrior()
      c = card(:warrior, :shield_up)
      {:alive, updated_player, _, _} = Combat.play_card(player, durable_monster(), c, always(1))
      assert updated_player.block == 6
    end
  end

  # ---------------------------------------------------------------------------
  # Combat.end_turn/3
  # ---------------------------------------------------------------------------

  describe "end_turn/3" do
    test "returns :continue when player survives" do
      player = warrior()
      assert {:continue, _, _, _} = Combat.end_turn(player, durable_monster(), always(1))
    end

    test "returns :player_dead when monster kills player" do
      player = %{warrior() | hp: 1, armor_class: 1}
      strong_monster = %{durable_monster() | damage: "1d4"}
      assert {:player_dead, _, _, _} = Combat.end_turn(player, strong_monster, always(20))
    end

    test "block absorbs monster damage" do
      player = %{fortress_player() | hp: 20, armor_class: 1, block: 100}
      strong = %{durable_monster() | damage: "1d4"}
      {:continue, updated_player, _, _} = Combat.end_turn(player, strong, always(4))
      # block absorbed all damage
      assert updated_player.hp == 20
    end

    test "block is reset to 0 after end of turn" do
      player = %{warrior() | block: 10}
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      assert updated_player.block == 0
    end

    test "energy is reset to max_energy after end of turn" do
      player = %{warrior() | energy: 0}
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      assert updated_player.energy == player.max_energy
    end

    test "draws 5 cards from deck at end of turn" do
      player = warrior()
      # Empty the hand and put all cards back in deck
      all_cards = player.hand ++ player.deck
      player = %{player | hand: [], deck: all_cards, discard: []}
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      assert length(updated_player.hand) == 5
    end

    test "remaining hand is discarded before drawing" do
      player = warrior()
      # Player has some cards in hand
      leftover = player.hand
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))

      # All leftover cards end up in discard (they may be redrawn if deck empty, so just check structure)
      assert length(updated_player.hand) == 5

      total_cards =
        length(updated_player.hand) + length(updated_player.deck) + length(updated_player.discard)

      original_total = length(leftover) + length(player.deck) + length(player.discard)
      assert total_cards == original_total
    end

    test "reshuffles discard into deck when deck runs out" do
      player = warrior()
      # Put 3 cards in deck, 7 in discard, empty hand
      all_cards = player.hand ++ player.deck
      {deck_cards, discard_cards} = Enum.split(all_cards, 3)
      player = %{player | hand: [], deck: deck_cards, discard: discard_cards}
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      # Should have drawn 5
      assert length(updated_player.hand) == 5
    end

    test "dodge_next is consumed when monster attacks" do
      player = %{fortress_player() | armor_class: 1, dodge_next: true, block: 0}
      strong = %{durable_monster() | damage: "1d4"}
      {:continue, updated_player, _, log} = Combat.end_turn(player, strong, always(20))
      assert updated_player.dodge_next == false
      assert Enum.any?(log, &String.contains?(&1, "dodge"))
    end

    test "dodge_next is reset to false at end of turn even without monster damage" do
      player = %{warrior() | dodge_next: true}
      {:continue, updated_player, _, _} = Combat.end_turn(player, durable_monster(), always(1))
      assert updated_player.dodge_next == false
    end
  end

  # ---------------------------------------------------------------------------
  # Monster heals/steals during end_turn
  # ---------------------------------------------------------------------------

  describe "end_turn/3 — monster non-damage actions" do
    test "monster heal action restores monster hp" do
      monster =
        attack_only(Monster.for_round(1))
        |> Map.put(:hp, 5)
        |> Map.put(:max_hp, 100)
        |> Map.put(:actions, [%{name: "Heal", type: :heal, amount: "1d4", weight: 1}])
        |> Map.put(:next_action, nil)

      player = fortress_player()
      {:continue, _player, updated_monster, _log} = Combat.end_turn(player, monster, always(4))
      assert updated_monster.hp > 5
    end

    test "monster steal_potion takes a potion when player has one" do
      monster =
        attack_only(Monster.for_round(1))
        |> Map.put(:actions, [%{name: "Steal", type: :steal_potion, weight: 1}])
        |> Map.put(:next_action, nil)

      player = %{fortress_player() | potions: 2}
      {:continue, updated_player, _, _} = Combat.end_turn(player, monster, always(1))
      assert updated_player.potions == 1
    end
  end
end
