```
┌─────────────────────────────────────────────────────────────────┐
│                        Browser / Client                         │
│                    Phoenix LiveView (WebSocket)                  │
└─────────────────────────┬───────────────────────────────────────┘
                          │  phx-click events
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DndWeb.GameLive                             │
│               lib/dnd_web/live/game_live.ex                     │
│                                                                 │
│  assigns: phase, player, monster, turn, log, upgrade_choices,   │
│           current_floor, dungeon_map, show_log                  │
│                                                                 │
│  phases:  :idle → :class_select → :map → :fighting             │
│              ↕                        ↕        ↕               │
│           :game_over              :rest    :reward              │
│           :victory                :inventory :deck_view         │
│                                                                 │
│  events:  start_game, choose_class, select_node                 │
│           play_card (phx-value-index={i})                       │
│           end_turn                                              │
│           use_potion                                            │
│           choose_upgrade, skip_reward                           │
│           open/close_inventory, equip/unequip_item              │
│           open/close_deck                                       │
│           toggle_log, toggle_qr, play_again                     │
└──────────────┬──────────────────────────────────────────────────┘
               │  uses
               ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DndWeb.GameComponents                         │
│           lib/dnd_web/live/game_components.ex                   │
│                                                                 │
│  Components:  highscore_list/1, dungeon_map_svg/1               │
│  Icon helpers: card_icon/1, intent_icon/1, action_damage_text/2 │
│  SVG helpers:  node_x/1, node_y/1, node_fill/3, node_stroke/2, │
│                node_icon/1, nodes_bottom_to_top/1               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        Game Core Layer                          │
│                   lib/dungeon_game/                             │
└──────────────┬──────────────────────────────────────────────────┘
               │  calls
     ┌─────────┼────────────┬──────────────────┐
     ▼         ▼            ▼                  ▼
┌─────────┐ ┌──────────┐ ┌────────────────┐ ┌───────────────┐
│ Player  │ │ Monster  │ │    Combat      │ │     Card      │
│player.ex│ │monster.ex│ │  combat.ex     │ │   card.ex     │
│         │ │          │ │                │ │               │
│%Player{}│ │%Monster{}│ │ play_card/5    │ │ %Card{}       │
│  hp     │ │  hp      │ │  → deduct      │ │  id, name     │
│  max_hp │ │  max_hp  │ │    energy      │ │  cost, effect │
│  ac     │ │  ac      │ │  → Card.apply  │ │  description  │
│  block  │ │  damage  │ │  → loot on die │ │               │
│  energy │ │  actions │ │ end_turn/3     │ │ all/1         │
│  hand   │ │ next_act │ │  → discard     │ │ starting_deck │
│  deck   │ │          │ │    hand        │ │ reward_pool/1 │
│  discard│ │for_round/│ │  → monster act │ │ apply/4       │
│  gold   │ │pick_act  │ │  → draw 5      │ └──────┬────────┘
│  potions│ │          │ │ attack/3       │        │ data
│  inv    │ │          │ │ apply_damage/2 │        ▼
│  equip* │ │          │ │ alive?/1       │ ┌───────────────┐
│         │ │          │ └───────┬────────┘ │ CardCatalog   │
│equip/2  │ │          │         │ uses     │card_catalog.ex│
│unequip/2│ │          │  ┌──────┴────────┐ │               │
└─────────┘ └──────────┘  │    Dice       │ │warrior_base/0 │
                           │   dice.ex    │ │warrior_extra/0│
                           │              │ │rogue_base/0   │
                           │ roll/2       │ │rogue_extra/0  │
                           │ "NdM" parser │ │mage_base/0    │
                           │ roller fn    │ │mage_extra/0   │
                           └──────┬───────┘ └───────────────┘
                                  │ also used by
                 ┌────────────────┴─────────────┐
                 ▼                              ▼
        ┌────────────────┐            ┌─────────────────┐
        │     Loot       │            │      Item       │
        │   loot.ex      │            │    item.ex      │
        │                │            │                 │
        │ roll/2         │            │ %Item{}         │
        │ {:gold, amt}   │            │  type           │
        │ {:item, ...}   │            │  name           │
        │ {:potion, 1}   │            │  bonus          │
        └────────────────┘            │                 │
                                      │ random/1        │
                                      └─────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      Support Modules                            │
│                                                                 │
│  PlayerClass   — class definitions + new_player/2              │
│  DungeonMap    — map generation + node traversal               │
│  MapNode       — node struct (:fight | :boss | :rest)          │
│  Highscore     — in-memory leaderboard (ETS)                   │
│  Portraits     — SVG avatar components                         │
└─────────────────────────────────────────────────────────────────┘

Card-based turn flow:
─────────────────────
  1. Enter fight: reset_for_new_fight (shuffle all cards, draw 5, energy = max)
  2. Player phase (repeat until "End Turn"):
       phx-click="play_card" phx-value-index={i}
       → Combat.play_card/5(player, monster, card, roller, idx)
           • deduct energy, move card hand→discard (by index, not value)
           • Card.apply/4 resolves the effect
           • if monster dies → loot, transition to :reward
  3. End Turn:
       phx-click="end_turn"
       → Combat.end_turn/3(player, monster, roller)
           • discard remaining hand
           • monster executes next_action (block absorbs damage)
           • reset block=0, energy=max_energy, dodge_next=false
           • draw 5 cards (reshuffle discard if deck empty)
       → GameLive picks new monster.next_action
  4. Results:
       {:player_dead, ...} → :game_over
       {:continue, ...}    → next turn

Card effect types:
──────────────────
  {:damage, dice}                 roll vs AC; deal damage on hit
  {:damage_nac, dice}             damage ignoring AC
  {:block, n}                     gain n block
  {:damage_and_block, dice, n}    damage + block
  {:multi_hit, dice, n}           n attacks each vs AC
  :shield_slam                    deal block as damage, clear block
  {:draw, n}                      draw n cards
  :dodge                          set dodge_next: true
  {:damage_and_draw, dice, n}     damage + draw n
  {:dodge_and_draw, n}            dodge + draw n
  {:block_and_draw, n, m}         gain n block + draw m
  {:damage_nac_and_draw, dice, n} damage (no AC) + draw n

Deck building:
──────────────
  Starting deck (10 cards):  class-specific mix from CardCatalog.*_base
  Reward pool   (20 cards):  4 classic + 16 extended from CardCatalog.*_extra
  After each room:           choose 1 of 3 random reward cards (or skip)
  Card added to:             player.discard (enters rotation next shuffle)

Monster tiers (by round):
──────────────────────────
  Rounds  1–3  → Goblin   (HP = 6 + round*5,  AC 9,  1d4)
  Rounds  4–6  → Orc      (HP = 25 + round*5, AC 11, 1d8)
  Rounds  7–9  → Troll    (HP = 45 + round*5, AC 13, 2d6)
  Rounds 10+   → Dragon   (HP = 70 + round*5, AC 15, 2d8)
  Floor→round: floor * 2 + 1

Roller injection (testability):
────────────────────────────────
  Production:  roller = &:rand.uniform/1
  Tests:       roller = fn _sides -> n end   (always/1 helper)
  Flows through: Combat.play_card → Card.apply → Dice.roll
                 Combat.end_turn  → Dice.roll (monster damage)
                                 → Loot.roll
```

## Key architectural properties

- **No database** — all state lives in the LiveView process
- **Pure core** — `Player`, `Monster`, `Combat`, `Card`, `Dice`, `Loot`, `Item` are stateless functional modules
- **Injected roller** — every function that rolls dice accepts a `roller` fn, keeping tests fully deterministic
- **Card-indexed removal** — `Combat.play_card/5` takes a `hand_idx` to use `List.delete_at` (not value equality), preventing hand reordering on duplicate cards
- **Monster intent** — `next_action` is pre-selected by `Monster.for_round` and refreshed by `GameLive` after `end_turn`; the UI always shows what the monster plans to do next
- **Separated concerns**:
  - `CardCatalog` holds raw card data (no logic)
  - `Card` holds effect resolution logic and deck-building API
  - `GameComponents` holds reusable UI components and icon/SVG helpers
  - `GameLive` holds only event handling, assigns management, and the top-level render template
