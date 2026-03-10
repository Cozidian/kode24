Scaffold the **red phase** of TDD for a new feature in this project.

Ask the user for the feature name and a brief description of what it should do. Then:

1. Determine where the tests belong:
   - Pure game logic (Combat, Monster, Player, Dice) → `test/dungeon_game/combat_test.exs` (or the relevant file)
   - LiveView UI behaviour → `test/dnd_web/game_live_test.exs`

2. Write 3–5 failing tests that cover the most important behaviours from backend to UI. Follow the project's test conventions exactly:
   - Use `always(n)` (`fn _sides -> n end`) as the roller to make outcomes deterministic
   - Use or extend the existing fixture helpers: `fragile_monster/0`, `durable_monster/0`, `fortress_player/0`, `attack_only/1`, `immune_monster/0`
   - For `Combat.tick/4` tests, pattern-match on `{:continue | :monster_dead | :player_dead, player, monster, log}`
   - For `Combat.act/4` tests (internal helper), pattern-match on `{:monster_dead | :alive, player, monster, log}`
   - For `Combat.bonus/4` tests (internal helper), pattern-match on `{:continue | :player_dead, player, monster, log}`
   - For LiveView tests, use `Phoenix.LiveViewTest`: navigate to `~p"/"`, click `"button[phx-click=start_game]"` to enter fighting phase, then assert with `has_element?/2`. Action buttons use `phx-value-action=attack|defend|heal`
   - Each test must have a single, descriptive name that states the expected behaviour

3. Run `mix test` on just the new tests and confirm they fail for the right reason (missing implementation, not a syntax error or wrong assertion).

4. Print a summary of what needs to be implemented to make the tests pass. Do NOT write any implementation code — the red phase ends here.
