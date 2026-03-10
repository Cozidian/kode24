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
│  assigns: phase, player, monster, round, turn, log             │
│                                                                 │
│  phases:  :idle ──► :fighting ──► :game_over                   │
│                         │                                       │
│  events:  start_game    │    player_action (attack/defend/heal) │
└─────────────────────────┼───────────────────────────────────────┘
                          │  calls
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Player     │  │   Monster    │  │   Combat     │
│  player.ex   │  │  monster.ex  │  │  combat.ex   │
│              │  │              │  │              │
│ %Player{}    │  │ %Monster{}   │  │ tick/4       │
│  name        │  │  name        │  │ attack/3     │
│  hp          │  │  hp          │  │ apply_damage │
│  max_hp      │  │  max_hp      │  │ alive?/1     │
│  damage      │  │  damage      │  │              │
│  armor_class │  │  armor_class │  │ returns:     │
│  potions     │  │  actions     │  │ :continue    │
│  xp          │  │  next_action │  │ :monster_dead│
│  level       │  │  xp          │  │ :player_dead │
│  gold        │  │  gold        │  └──────┬───────┘
│              │  │              │         │ uses
│ level_for_xp │  │ for_round/1  │  ┌──────┴───────┐
│ apply_level  │  │ pick_action  │  │              │
│   _up/2      │  │              │  │    Dice      │
└──────────────┘  └──────────────┘  │   dice.ex    │
                                    │              │
                                    │ roll/2       │
                                    │ "NdM" parser │
                                    │ roller fn    │
                                    └──────┬───────┘
                                           │ also used by
                                    ┌──────┴───────┐
                                    │    Loot      │
                                    │   loot.ex    │
                                    │              │
                                    │ roll/2       │
                                    │ {:gold, amt} │
                                    │ :nothing     │
                                    └──────────────┘

Data flow for a single turn:
─────────────────────────────
  1. User clicks Attack/Defend/Heal
  2. GameLive.handle_event("player_action", ...)
  3. Combat.tick(player, monster, action, roller)
       ├─ player acts   → Dice.roll + apply_damage
       ├─ monster dies? → apply XP, apply_level_up, Loot.roll
       └─ monster acts  → pick_action + execute_action
  4. Pattern-match result tuple
       ├─ {:continue, ...}     → update assigns, refresh next_action
       ├─ {:monster_dead, ...} → spawn next monster (Monster.for_round)
       └─ {:player_dead, ...}  → phase: :game_over
  5. LiveView re-renders diff to browser

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
- **Pure core** — `Player`, `Monster`, `Combat`, `Dice`, `Loot` are stateless functional modules
- **Injected roller** — every function that rolls dice accepts a `roller` fn, keeping tests fully deterministic
- **Monster intent** — `next_action` is pre-selected and stored on the monster struct so the UI can show it before the player acts; refreshed by `GameLive` after each turn, not inside `Combat`
