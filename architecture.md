```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser / Client                         │
│                    Phoenix LiveView (WebSocket)                  │
└─────────────────────────┬───────────────────────────────────────┘
                          │  phx-click events
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DndWeb.GameLive                             │
│                   lib/dnd_web/live/game_live.ex                 │
│                                                                 │
│  assigns: phase, player, monster, round, turn, log              │
│                                                                 │
│  phases:  :idle ──► :fighting ──► :game_over                   │
│                         │                                       │
│  events:  start_game    │  player_action (attack/defend/heal)   │
│    open/close_inventory │                                       │
│    equip/unequip_item   │                                       │
└─────────────────────────┼───────────────────────────────────────┘
                          │  calls
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐
│   Player     │  │   Monster    │  │         Combat           │
│  player.ex   │  │  monster.ex  │  │        combat.ex         │
│              │  │              │  │                          │
│ %Player{}    │  │ %Monster{}   │  │  tick/4  (main API)      │
│  name        │  │  name        │  │    :attack → hit/miss    │
│  hp/max_hp   │  │  hp/max_hp   │  │    :defend → +5 AC       │
│  damage      │  │  damage      │  │    :heal   → restore hp  │
│  armor_class │  │  armor_class │  │  → monster counter-attack│
│  potions     │  │  actions     │  │  returns:                │
│  xp/level    │  │  next_action │  │    :monster_dead         │
│  gold        │  │  xp/gold     │  │    :continue             │
│  inventory   │  │              │  │    :player_dead          │
│  equipped_*  │  │ for_round/1  │  │                          │
│  bonus_*     │  │ pick_action  │  │  act/4   (internal)      │
│  defending   │  │              │  │  bonus/4 (internal)      │
│              │  │              │  └────────────┬─────────────┘
│ xp_threshold │  │              │               │ uses
│ level_for_xp │  │              │        ┌──────┴───────┐
│ apply_level  │  │              │        │    Dice      │
│   _up/2      │  │              │        │   dice.ex    │
│ equip/2      │  │              │        │              │
│ unequip/2    │  │              │        │ roll/2       │
└──────────────┘  └──────────────┘        │ "NdM" parser │
                                          │ roller fn    │
                                          └──────┬───────┘
                                                 │ also used by
                              ┌──────────────────┴─────────┐
                              │                            │
                     ┌────────┴─────┐            ┌────────┴─────┐
                     │    Loot      │            │     Item     │
                     │   loot.ex    │            │   item.ex    │
                     │              │            │              │
                     │ roll/2       │            │ %Item{}      │
                     │ {:gold, amt} │            │  type        │
                     │ {:item, ...} │            │  name        │
                     │ {:potion, 1} │            │  bonus       │
                     └──────────────┘            │              │
                                                 │ random/1     │
                                                 └──────────────┘

Turn flow (single action per turn):
────────────────────────────────────
  1. User clicks Attack / Defend / Heal
  2. GameLive.handle_event("player_action", ...)
  3. Combat.tick(player, monster, action, roller)
       ├─ :attack → player hits/misses monster
       │    └─ monster dead? → XP, level_up, Loot.roll
       ├─ :defend → player.defending = true (+5 AC for incoming attack)
       └─ :heal   → player drinks potion (2d4 HP)
       └─ monster counter-attacks (always, respects defending flag)
  4. Pattern-match result
       ├─ {:monster_dead, ...} → spawn next monster, reset turn
       ├─ {:continue, ...}     → refresh next_action, increment turn
       └─ {:player_dead, ...}  → phase: :game_over

Roller injection (testability):
─────────────────────────────
  Production:  roller = &:rand.uniform/1
  Tests:       roller = fn _sides -> n end   (always/1 helper)
  Flows through: Combat.tick → Dice.roll
                           └─► Loot.roll
                           └─► Player.apply_level_up
```

Key architectural properties:
- **No database** — all state lives in the LiveView process
- **Pure core** — `Player`, `Monster`, `Combat`, `Dice`, `Loot`, `Item` are stateless functional modules
- **Injected roller** — every function that rolls dice accepts a `roller` fn, keeping tests fully deterministic
- **Single-action turns** — `tick/4` handles the player's action and the monster counter-attack in one call
- **Monster intent** — `next_action` is pre-selected by `Monster.for_round` and refreshed by `GameLive` after each turn; the UI always shows what the monster plans to do next
- **Defend carry-over** — `player.defending` is set inside `tick(:defend)` via `act/4` and consumed + cleared by `bonus/4` during the monster counter-attack within the same `tick` call
