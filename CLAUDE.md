# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix test                          # run all tests
mix test test/path/to_test.exs    # run a single test file
mix test test/path/to_test.exs:42 # run a single test by line number
mix test --failed                 # re-run only previously failing tests
mix phx.server                    # start dev server at localhost:4000
mix precommit                     # compile (warnings as errors), format, and test — run before finishing
```

## Architecture

This is a single-page, database-free dungeon crawler game. All game state lives in the LiveView process — there is no Ecto schema or database involved despite the Ecto dependency being present.

### Core game layer (`lib/dungeon_game/`)

Pure functional modules with no side effects or process state:

- **`Player`** — plain struct (`name, hp, max_hp, damage, armor_class, potions, xp, level, gold, inventory, equipped_*, bonus_damage, bonus_ac, defending`)
- **`Monster`** — plain struct with round-based scaling; `Monster.for_round/1` spawns the correct tier (Goblin → Orc → Troll → Dragon, every 3 rounds). Stores a pre-selected `next_action` so the UI can show the monster's intent before the player acts.
- **`Combat`** — all combat resolution lives here. Each turn is a single call:
  - `Combat.tick/4` — resolves the player's action (`attack | defend | heal`), then the monster counter-attacks. Returns `{:continue | :monster_dead | :player_dead, player, monster, log}`.
  - `Combat.act/4` and `Combat.bonus/4` are internal helpers used by `tick/4`; tests may call them directly.
  - The `roller` argument (`fn sides -> integer()`) is injected for determinism in tests.
- **`Dice`** — parses dice notation (`"2d6"`) and rolls with the same injectable roller pattern.
- **`Loot`** — rolls for drops on monster death: `{:gold, amount}`, `{:item, %Item{}}`, `{:potion, 1}` (each 50% independent).
- **`Item`** — loot item struct with `type` (`:weapon | :armor | :helm | :boots`), `name`, `bonus`.

### Web layer (`lib/dnd_web/`)

A single LiveView (`GameLive`) drives the entire game. It has four phases stored in the `phase` assign: `:idle`, `:fighting`, `:inventory`, `:game_over`.

Events:
- `player_action` with `phx-value-action="attack|defend|heal"` → calls `Combat.tick/4`; on `:continue` refreshes `next_action`; on `:monster_dead` spawns next monster; on `:player_dead` transitions to `:game_over`

### Testing patterns

**All new features must be developed TDD-style: write failing tests first, then implement, then refactor.** The red → green → refactor cycle is mandatory — never write implementation code before a covering test exists and fails for the right reason.

Three project skills map directly to this cycle:
- `/tdd` — scaffolds 3–5 failing tests for a new feature (red phase)
- `/simplify` — reviews passing code for duplication and clarity (refactor phase)
- `/precommit` — runs `mix precommit` as the final gate before finishing

Tests use a deterministic roller helper `always(n)` (`fn _sides -> n end`) to force specific hit/damage outcomes. Common fixtures:

- `fragile_monster/0` — AC 1, so any roll hits
- `durable_monster/0` — 1000 HP, AC 1
- `fortress_player/0` — AC 21, effectively unhittable
- `attack_only(monster)` — strips non-attack actions for deterministic monster counter-attacks

For `Combat.tick/4` tests, pattern-match on `{:continue | :monster_dead | :player_dead, player, monster, log}`.
For `Combat.act/4` tests (internal), pattern-match on `{:monster_dead | :alive, player, monster, log}`.
For `Combat.bonus/4` tests (internal), pattern-match on `{:continue | :player_dead, player, monster, log}`.

LiveView tests use `Phoenix.LiveViewTest`: navigate to `~p"/"`, click `"button[phx-click=start_game]"` to enter the fighting phase, then assert on elements. Action buttons have `phx-value-action=attack|defend|heal`.

### Key conventions

- The `roller` parameter flows through every combat function — always thread it through rather than calling `:rand.uniform/1` directly inside logic.
- Monster `next_action` is refreshed in the `player_action` handler after each turn, not inside `Combat.tick`.
- `player.defending` is set by `tick(:defend)` via `act/4` internally and consumed + cleared by `bonus/4` during the monster's counter-attack.
- `put_log/3` keeps only the last 5 log entries.
- `mix precommit` runs `compile --warning-as-errors` so the build must be warning-free.
