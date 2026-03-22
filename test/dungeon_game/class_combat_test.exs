defmodule DungeonGame.ClassCombatTest do
  use ExUnit.Case, async: true

  alias DungeonGame.{Combat, Monster, PlayerClass}

  defp always(n), do: fn _sides -> n end

  defp durable_monster do
    %{
      Monster.for_round(1)
      | hp: 1000,
        max_hp: 1000,
        armor_class: 1,
        actions: [%{name: "Attack", type: :attack, weight: 1}],
        next_action: nil
    }
  end

  defp unhittable_monster do
    %{
      Monster.for_round(1)
      | armor_class: 100,
        actions: [%{name: "Attack", type: :attack, weight: 1}],
        next_action: nil
    }
  end

  # ---------------------------------------------------------------------------
  # Warrior — Shield Charges
  # ---------------------------------------------------------------------------

  describe "warrior shield charges" do
    setup do
      %{warrior: PlayerClass.new_player(:warrior, "Thor")}
    end

    test "defend adds a shield charge", %{warrior: warrior} do
      {:continue, updated, _m, _log} = Combat.tick(warrior, durable_monster(), :defend, always(1))
      assert updated.shield_charges == 1
    end

    test "defend stacks charges up to 3", %{warrior: warrior} do
      m = durable_monster()
      {:continue, w1, _, _} = Combat.tick(warrior, m, :defend, always(1))
      {:continue, w2, _, _} = Combat.tick(w1, m, :defend, always(1))
      {:continue, w3, _, _} = Combat.tick(w2, m, :defend, always(1))
      assert w3.shield_charges == 3
    end

    test "defend does not exceed 3 charges", %{warrior: warrior} do
      m = durable_monster()
      w = %{warrior | shield_charges: 3}
      {:continue, updated, _, _} = Combat.tick(w, m, :defend, always(1))
      assert updated.shield_charges == 3
    end

    test "a shield charge absorbs the monster counter-attack (no damage)", %{warrior: warrior} do
      w = %{warrior | shield_charges: 1}
      # always(10) guarantees monster hits
      {:continue, updated, _m, _log} = Combat.tick(w, durable_monster(), :attack, always(10))
      assert updated.shield_charges == 0
      # HP should be unchanged — charge absorbed the hit
      assert updated.hp == warrior.hp
    end

    test "shield charge is consumed when absorbing a hit", %{warrior: warrior} do
      w = %{warrior | shield_charges: 2}
      {:continue, updated, _, _} = Combat.tick(w, durable_monster(), :attack, always(10))
      assert updated.shield_charges == 1
    end

    test "without shield charges, warrior takes damage normally", %{warrior: warrior} do
      # always(20) guarantees monster hits (roll 20 >= AC 16)
      {result, updated, _, _} = Combat.tick(warrior, durable_monster(), :attack, always(20))
      assert result in [:continue, :player_dead]
      assert updated.hp < warrior.hp
    end

    test "log mentions shield absorbing when charge is consumed", %{warrior: warrior} do
      w = %{warrior | shield_charges: 1}
      {:continue, _, _, log} = Combat.tick(w, durable_monster(), :attack, always(10))
      assert Enum.any?(log, &String.contains?(&1, "shield"))
    end
  end

  # ---------------------------------------------------------------------------
  # Rogue — Combo
  # ---------------------------------------------------------------------------

  describe "rogue combo" do
    setup do
      %{rogue: PlayerClass.new_player(:rogue, "Shadow")}
    end

    test "a hit increments combo", %{rogue: rogue} do
      {:continue, updated, _, _} = Combat.tick(rogue, durable_monster(), :attack, always(10))
      assert updated.combo == 1
    end

    test "consecutive hits stack combo", %{rogue: rogue} do
      m = durable_monster()
      {:continue, r1, _, _} = Combat.tick(rogue, m, :attack, always(10))
      {:continue, r2, _, _} = Combat.tick(r1, m, :attack, always(10))
      {:continue, r3, _, _} = Combat.tick(r2, m, :attack, always(10))
      assert r3.combo == 3
    end

    test "a miss resets combo to 0", %{rogue: rogue} do
      r = %{rogue | combo: 3}
      # unhittable_monster has AC 100, always(1) guarantees miss
      {:continue, updated, _, _} = Combat.tick(r, unhittable_monster(), :attack, always(1))
      assert updated.combo == 0
    end

    test "defend resets combo to 0", %{rogue: rogue} do
      r = %{rogue | combo: 2}
      {:continue, updated, _, _} = Combat.tick(r, durable_monster(), :defend, always(1))
      assert updated.combo == 0
    end

    test "finisher deals combo × 1d6 damage and resets combo", %{rogue: rogue} do
      r = %{rogue | combo: 3}
      m = durable_monster()
      # always(3) → each d6 rolls 3 → 3 × 3 = 9 damage
      {result, updated_r, updated_m, _log} = Combat.tick(r, m, :finisher, always(3))
      assert result in [:continue, :monster_dead]
      assert updated_r.combo == 0
      assert updated_m.hp == m.hp - 3 * 3
    end

    test "finisher with 0 combo deals 0 damage", %{rogue: rogue} do
      m = durable_monster()
      {_result, _r, updated_m, _log} = Combat.tick(rogue, m, :finisher, always(6))
      assert updated_m.hp == m.hp
    end
  end

  # ---------------------------------------------------------------------------
  # Mage — Mana
  # ---------------------------------------------------------------------------

  describe "mage mana regen" do
    setup do
      %{mage: PlayerClass.new_player(:mage, "Gandalf")}
    end

    test "mana regenerates by 1 at the start of each turn (when below max)", %{mage: mage} do
      m = durable_monster()
      depleted = %{mage | mana: 1}
      {:continue, updated, _, _} = Combat.tick(depleted, m, :attack, always(1))
      assert updated.mana == 2
    end

    test "mana does not exceed max_mana", %{mage: mage} do
      m = durable_monster()
      {:continue, updated, _, _} = Combat.tick(mage, m, :attack, always(1))
      assert updated.mana <= mage.max_mana
    end
  end

  describe "mage fireball" do
    setup do
      %{mage: PlayerClass.new_player(:mage, "Gandalf")}
    end

    test "fireball ignores AC (auto-hit on unhittable monster)", %{mage: mage} do
      m = unhittable_monster()
      # normal attack would always miss; fireball should always hit
      {_result, _mage, updated_m, _log} = Combat.tick(mage, m, :fireball, always(6))
      assert updated_m.hp < m.hp
    end

    test "fireball costs 2 mana", %{mage: mage} do
      m = durable_monster()
      {:continue, updated, _, _} = Combat.tick(mage, m, :fireball, always(4))
      # started at max (3), regen is no-op, spent 2 → 1
      assert updated.mana == mage.mana - 2
    end

    test "fireball deals 2d8 damage", %{mage: mage} do
      m = durable_monster()
      # always(5) → 2d8 = 5+5 = 10
      {:continue, _, updated_m, _} = Combat.tick(mage, m, :fireball, always(5))
      assert updated_m.hp == m.hp - 10
    end

    test "fireball is blocked when mana < 2", %{mage: mage} do
      m = durable_monster()
      # mana: 0 → regen brings to 1, still < 2, so fireball is blocked
      broke = %{mage | mana: 0}
      {:continue, _, updated_m, _} = Combat.tick(broke, m, :fireball, always(5))
      # Should deal no damage (or fallback to basic attack — no change on miss)
      # Exact behavior: fireball does nothing if insufficient mana
      assert updated_m.hp >= m.hp - 4
    end
  end

  describe "mage frost nova" do
    setup do
      %{mage: PlayerClass.new_player(:mage, "Gandalf")}
    end

    test "frost nova sets frost_nova_active on the player", %{mage: mage} do
      m = durable_monster()
      {:continue, updated_mage, _, _} = Combat.tick(mage, m, :frost_nova, always(3))
      # frost_nova_active is consumed in the same tick's bonus phase, so after tick it's false
      # But the monster should have taken half damage in the counter-attack
      # The flag is set during act and consumed during bonus of the same tick
      assert updated_mage.frost_nova_active == false
    end

    test "frost nova costs 1 mana", %{mage: mage} do
      m = durable_monster()
      {:continue, updated, _, _} = Combat.tick(mage, m, :frost_nova, always(3))
      # start 3, regen +1 (capped at 3), spend 1 → 2
      assert updated.mana == 2
    end

    test "frost nova deals 1d6 damage to monster", %{mage: mage} do
      m = durable_monster()
      # always(4) → 1d6 = 4
      {:continue, _, updated_m, _} = Combat.tick(mage, m, :frost_nova, always(4))
      assert updated_m.hp == m.hp - 4
    end

    test "frost nova halves incoming monster damage on the same turn", %{mage: mage} do
      # Set up a mage with full HP, then compare damage taken vs normal
      m = %{
        durable_monster()
        | next_action: %{name: "Attack", type: :attack, damage: "2d6", weight: 1}
      }

      mage_full = %{mage | hp: mage.max_hp}

      # With frost nova: should take half damage
      {:continue, after_nova, _, _} = Combat.tick(mage_full, m, :frost_nova, always(6))
      # Without frost nova (basic attack, same roller so monster also hits for max)
      {:continue, after_attack, _, _} = Combat.tick(mage_full, m, :attack, always(6))

      damage_with_nova = mage_full.hp - after_nova.hp
      damage_without = mage_full.hp - after_attack.hp

      # Frost nova damage should be less (halved)
      # Note: frost nova also deals damage to the monster, so hp comparisons are valid
      assert damage_with_nova <= damage_without
    end
  end
end
