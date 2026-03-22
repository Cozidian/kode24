defmodule DungeonGame.CardTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Card, Monster, Player}

  defp always(n), do: fn _sides -> n end

  defp fragile_monster do
    m = Monster.for_round(1)
    %{m | armor_class: 1, hp: 100, max_hp: 100}
  end

  # A minimal player with card fields populated
  defp fresh_player(class \\ :warrior) do
    %Player{
      class: class,
      hp: 20,
      max_hp: 20,
      armor_class: 10,
      bonus_ac: 0,
      bonus_damage: 0,
      damage: "1d6",
      hand: [],
      deck: [],
      discard: [],
      energy: 3,
      max_energy: 3,
      block: 0,
      dodge_next: false
    }
  end

  # ---------------------------------------------------------------------------
  # Card.all/1
  # ---------------------------------------------------------------------------

  describe "Card.all/1" do
    test "warrior has 23 cards" do
      assert length(Card.all(:warrior)) == 23
    end

    test "rogue has 23 cards" do
      assert length(Card.all(:rogue)) == 23
    end

    test "mage has 23 cards" do
      assert length(Card.all(:mage)) == 23
    end

    test "each card has a non-empty name and description" do
      for class <- [:warrior, :rogue, :mage], card <- Card.all(class) do
        assert is_binary(card.name) and card.name != ""
        assert is_binary(card.description) and card.description != ""
      end
    end

    test "each card has a non-negative cost" do
      for class <- [:warrior, :rogue, :mage], card <- Card.all(class) do
        assert card.cost >= 0
      end
    end

    test "warrior cards include cleave, shield_up, iron_wave, bash, shield_slam, battle_cry, bulwark" do
      ids = Card.all(:warrior) |> Enum.map(& &1.id)
      assert :cleave in ids
      assert :shield_up in ids
      assert :iron_wave in ids
      assert :bash in ids
      assert :shield_slam in ids
      assert :battle_cry in ids
      assert :bulwark in ids
    end

    test "rogue cards include stab, backstab, blade_dance, evade, finisher, preparation, cheap_shot" do
      ids = Card.all(:rogue) |> Enum.map(& &1.id)
      assert :stab in ids
      assert :backstab in ids
      assert :blade_dance in ids
      assert :evade in ids
      assert :finisher in ids
      assert :preparation in ids
      assert :cheap_shot in ids
    end

    test "mage cards include magic_missile, fireball, frost_nova, arcane_bolt, chain_lightning, mana_shield, concentration" do
      ids = Card.all(:mage) |> Enum.map(& &1.id)
      assert :magic_missile in ids
      assert :fireball in ids
      assert :frost_nova in ids
      assert :arcane_bolt in ids
      assert :chain_lightning in ids
      assert :mana_shield in ids
      assert :concentration in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Card.starting_deck/1
  # ---------------------------------------------------------------------------

  describe "Card.starting_deck/1" do
    test "warrior starting deck has 10 cards" do
      assert length(Card.starting_deck(:warrior)) == 10
    end

    test "rogue starting deck has 10 cards" do
      assert length(Card.starting_deck(:rogue)) == 10
    end

    test "mage starting deck has 10 cards" do
      assert length(Card.starting_deck(:mage)) == 10
    end

    test "warrior deck contains 5 cleave, 4 shield_up, 1 iron_wave" do
      deck = Card.starting_deck(:warrior)
      ids = Enum.map(deck, & &1.id)
      assert Enum.count(ids, &(&1 == :cleave)) == 5
      assert Enum.count(ids, &(&1 == :shield_up)) == 4
      assert Enum.count(ids, &(&1 == :iron_wave)) == 1
    end

    test "rogue deck contains 5 stab, 4 backstab, 1 evade" do
      deck = Card.starting_deck(:rogue)
      ids = Enum.map(deck, & &1.id)
      assert Enum.count(ids, &(&1 == :stab)) == 5
      assert Enum.count(ids, &(&1 == :backstab)) == 4
      assert Enum.count(ids, &(&1 == :evade)) == 1
    end

    test "mage deck contains 5 magic_missile, 4 mana_shield, 1 frost_nova" do
      deck = Card.starting_deck(:mage)
      ids = Enum.map(deck, & &1.id)
      assert Enum.count(ids, &(&1 == :magic_missile)) == 5
      assert Enum.count(ids, &(&1 == :mana_shield)) == 4
      assert Enum.count(ids, &(&1 == :frost_nova)) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Card.reward_pool/1
  # ---------------------------------------------------------------------------

  describe "Card.reward_pool/1" do
    test "warrior reward pool has 20 cards" do
      assert length(Card.reward_pool(:warrior)) == 20
    end

    test "rogue reward pool has 20 cards" do
      assert length(Card.reward_pool(:rogue)) == 20
    end

    test "mage reward pool has 20 cards" do
      assert length(Card.reward_pool(:mage)) == 20
    end

    test "warrior reward pool contains bash, shield_slam, battle_cry, bulwark" do
      ids = Card.reward_pool(:warrior) |> Enum.map(& &1.id)
      assert :bash in ids
      assert :shield_slam in ids
      assert :battle_cry in ids
      assert :bulwark in ids
    end

    test "rogue reward pool contains blade_dance, evade, finisher, preparation" do
      ids = Card.reward_pool(:rogue) |> Enum.map(& &1.id)
      assert :blade_dance in ids
      assert :evade in ids
      assert :finisher in ids
      assert :preparation in ids
    end

    test "mage reward pool contains fireball, chain_lightning, mana_shield, concentration" do
      ids = Card.reward_pool(:mage) |> Enum.map(& &1.id)
      assert :fireball in ids
      assert :chain_lightning in ids
      assert :mana_shield in ids
      assert :concentration in ids
    end
  end

  # ---------------------------------------------------------------------------
  # Card.apply/4 — damage effects
  # ---------------------------------------------------------------------------

  describe "Card.apply/4 - :damage effect" do
    test "deals damage on a hit" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :cleave))
      player = fresh_player()
      monster = fragile_monster()
      # always(20) hits, always(8) = max 1d8 roll
      {_player, updated_monster, log} = Card.apply(card, player, monster, always(8))
      assert updated_monster.hp < monster.hp
      assert Enum.any?(log, &String.contains?(&1, "damage"))
    end

    test "misses against high AC" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :cleave))
      player = fresh_player()
      monster = %{fragile_monster() | armor_class: 21}
      {_player, updated_monster, log} = Card.apply(card, player, monster, always(1))
      assert updated_monster.hp == monster.hp
      assert Enum.any?(log, &String.contains?(&1, "Miss"))
    end
  end

  describe "Card.apply/4 - :damage_nac effect" do
    test "deals damage ignoring AC (hits even high AC)" do
      card = Enum.find(Card.all(:mage), &(&1.id == :magic_missile))
      player = fresh_player(:mage)
      monster = %{fragile_monster() | armor_class: 21}
      {_player, updated_monster, _log} = Card.apply(card, player, monster, always(4))
      assert updated_monster.hp < monster.hp
    end
  end

  describe "Card.apply/4 - :block effect" do
    test "increases player block" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :shield_up))
      player = fresh_player()
      {updated_player, _monster, log} = Card.apply(card, player, fragile_monster(), always(1))
      assert updated_player.block > 0
      assert Enum.any?(log, &String.contains?(&1, "block"))
    end
  end

  describe "Card.apply/4 - :damage_and_block effect" do
    test "deals damage and gains block simultaneously" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :iron_wave))
      player = fresh_player()
      monster = fragile_monster()
      {updated_player, updated_monster, _log} = Card.apply(card, player, monster, always(6))
      assert updated_monster.hp < monster.hp
      assert updated_player.block > 0
    end
  end

  describe "Card.apply/4 - :multi_hit effect" do
    test "hits multiple times" do
      card = Enum.find(Card.all(:rogue), &(&1.id == :blade_dance))
      player = fresh_player(:rogue)
      monster = fragile_monster()
      {_player, updated_monster, log} = Card.apply(card, player, monster, always(4))
      # 3 hits of 1d4=4 each → 12 total damage
      assert monster.hp - updated_monster.hp == 12
      assert length(log) == 3
    end
  end

  describe "Card.apply/4 - :shield_slam effect" do
    test "deals block as damage and clears block" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :shield_slam))
      player = %{fresh_player() | block: 8}
      monster = fragile_monster()
      {updated_player, updated_monster, log} = Card.apply(card, player, monster, always(1))
      assert updated_monster.hp == monster.hp - 8
      assert updated_player.block == 0
      assert Enum.any?(log, &String.contains?(&1, "8"))
    end

    test "deals 0 damage and logs when block is 0" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :shield_slam))
      player = %{fresh_player() | block: 0}
      monster = fragile_monster()
      {_player, updated_monster, _log} = Card.apply(card, player, monster, always(1))
      assert updated_monster.hp == monster.hp
    end
  end

  describe "Card.apply/4 - :draw effect" do
    test "draws cards from deck into hand" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :battle_cry))
      # Give player a deck with 3 cards
      extra_cards = Card.starting_deck(:warrior) |> Enum.take(3)
      player = %{fresh_player() | deck: extra_cards}
      {updated_player, _monster, _log} = Card.apply(card, player, fragile_monster(), always(1))
      # Battle Cry draws 2
      assert length(updated_player.hand) == 2
      assert length(updated_player.deck) == 1
    end

    test "draws fewer cards if deck is small" do
      card = Enum.find(Card.all(:warrior), &(&1.id == :battle_cry))
      one_card = Card.starting_deck(:warrior) |> Enum.take(1)
      player = %{fresh_player() | deck: one_card}
      {updated_player, _monster, _log} = Card.apply(card, player, fragile_monster(), always(1))
      # Only 1 card in deck, so only 1 drawn
      assert length(updated_player.hand) == 1
    end
  end

  describe "Card.apply/4 - :dodge effect" do
    test "sets dodge_next on player" do
      card = Enum.find(Card.all(:rogue), &(&1.id == :evade))
      player = fresh_player(:rogue)
      {updated_player, _monster, log} = Card.apply(card, player, fragile_monster(), always(1))
      assert updated_player.dodge_next == true
      assert Enum.any?(log, &String.contains?(&1, "dodge"))
    end
  end

  describe "Card.apply/4 - :damage_and_draw effect" do
    test "deals damage and draws a card (Backstab)" do
      card = Enum.find(Card.all(:rogue), &(&1.id == :backstab))
      extra_cards = Card.starting_deck(:rogue) |> Enum.take(2)
      player = %{fresh_player(:rogue) | deck: extra_cards}
      monster = fragile_monster()

      {updated_player, updated_monster, _log} =
        Card.apply(card, player, monster, always(4))

      # Backstab deals damage (hit against AC 1 with roll always(4))
      assert updated_monster.hp < monster.hp
      # Draws 1 card
      assert length(updated_player.hand) == 1
    end
  end
end
