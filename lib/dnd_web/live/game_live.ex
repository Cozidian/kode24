defmodule DndWeb.GameLive do
  use DndWeb, :live_view

  alias DungeonGame.{
    Card,
    Combat,
    DungeonMap,
    Highscore,
    Loot,
    Monster,
    Player,
    PlayerClass,
    Shop
  }

  alias DndWeb.{GameComponents, Portraits}

  import DndWeb.GameComponents, only: [card_icon: 1, intent_icon: 1, action_damage_text: 2]

  # ---------------------------------------------------------------------------
  # Lifecycle
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        phase: :idle,
        player: nil,
        monster: nil,
        dungeon_map: nil,
        current_floor: 0,
        turn: 0,
        log: [],
        upgrade_choices: [],
        elite_loot_choices: [],
        post_elite_phase: :map,
        shop_inventory: [],
        pending_floor: 0,
        pending_name: nil,
        highscores: Highscore.list(),
        show_qr: false,
        show_log: false
      )

    {:ok, socket, layout: false}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 flex flex-col items-center justify-center p-3 sm:p-8 font-mono select-none">
      <h1 class="text-3xl sm:text-6xl font-bold mb-4 sm:mb-10 text-yellow-400 tracking-tight">
        ⚔ TDD Dungeon Crawler
      </h1>

      <%!-- Idle state --%>
      <div
        :if={@phase == :idle}
        class="bg-gray-800 rounded-2xl p-6 sm:p-12 text-center shadow-2xl w-full max-w-lg"
      >
        <Portraits.player class="w-32 h-40 mx-auto mb-6 drop-shadow-lg" />
        <p class="text-lg sm:text-2xl text-gray-300 mb-5 sm:mb-8">
          Brave TDD adventurer, do you dare enter the dungeon?
        </p>
        <GameComponents.highscore_list entries={@highscores} class="mb-8 w-full" />
        <form phx-submit="start_game" class="flex flex-col gap-4">
          <input
            name="username"
            type="text"
            placeholder="Enter your name"
            required
            class="bg-gray-700 text-gray-100 text-xl text-center px-6 py-3 rounded-xl border border-gray-600 focus:outline-none focus:border-yellow-400"
          />
          <button
            type="submit"
            class="bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold text-lg sm:text-2xl px-6 sm:px-10 py-3 sm:py-4 rounded-xl transition-all cursor-pointer"
          >
            Start Game
          </button>
        </form>
      </div>

      <%!-- Class Select --%>
      <div :if={@phase == :class_select} data-testid="class-select" class="w-full max-w-2xl space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-yellow-400">Choose Your Class</h2>
          <p class="text-gray-400 mt-2">
            Who will brave the dungeon, <span class="text-white font-bold">{@pending_name}</span>?
          </p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div
            :for={class <- PlayerClass.all()}
            class="bg-gray-800 rounded-2xl p-6 shadow-xl border border-gray-700 hover:border-yellow-500 transition-all flex flex-col"
          >
            <div class="text-5xl text-center mb-3">{class.icon}</div>
            <div class="text-xl font-bold text-white text-center mb-1">{class.name}</div>
            <div class="text-xs text-gray-400 text-center mb-3">
              HP: {class.hp} | AC: {class.armor_class} | DMG: {class.damage}
            </div>
            <p class="text-gray-300 text-sm flex-1 mb-4">{class.description}</p>
            <button
              phx-click="choose_class"
              phx-value-class={class.id}
              class="w-full bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold py-3 rounded-xl transition-all cursor-pointer"
            >
              Play as {class.name}
            </button>
          </div>
        </div>
      </div>

      <%!-- Dungeon Map --%>
      <div :if={@phase == :map} class="w-full max-w-2xl space-y-4">
        <div class="text-center flex items-center justify-between px-2">
          <span data-testid="player-name-map" class="text-yellow-400 font-bold text-lg">
            {@player.name}
          </span>
          <span class="text-gray-400 text-sm">HP: {@player.hp}/{@player.max_hp}</span>
        </div>

        <div data-testid="dungeon-map" class="bg-gray-800 rounded-2xl p-4 shadow-xl">
          <h2 class="text-center text-lg font-bold text-gray-300 mb-4 uppercase tracking-widest">
            Dungeon Map
          </h2>
          <GameComponents.dungeon_map_svg map={@dungeon_map} />
        </div>

        <p class="text-center text-gray-500 text-sm">Select a node to continue your journey</p>
      </div>

      <%!-- Shop screen --%>
      <div :if={@phase == :shop} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-yellow-400">🏪 Merchant</h2>
          <p class="text-gray-400 text-sm mt-1">
            Gold: <span class="text-yellow-400 font-bold">{@player.gold}</span>
          </p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
          <div
            :for={{entry, idx} <- Enum.with_index(@shop_inventory)}
            class="bg-gray-800 rounded-2xl p-5 shadow-xl border border-gray-600 hover:border-yellow-500 transition-all flex flex-col"
          >
            <div class="text-4xl text-center mb-2">{shop_entry_icon(entry)}</div>
            <div class="text-base font-bold text-yellow-300 text-center mb-1">
              {shop_entry_name(entry)}
            </div>
            <p class="text-gray-400 text-xs text-center flex-1 mb-3">
              {shop_entry_desc(entry)}
            </p>
            <div class="text-center text-yellow-400 font-bold text-sm mb-3">
              🪙 {elem(entry, 2)} gold
            </div>
            <button
              phx-click="buy_item"
              phx-value-index={idx}
              disabled={@player.gold < elem(entry, 2)}
              class="w-full bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold py-2 rounded-xl transition-all cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100"
            >
              Buy
            </button>
          </div>
        </div>
        <div :if={@shop_inventory == []} class="text-center text-gray-500 italic py-8">
          The merchant has nothing left to sell.
        </div>
        <button
          phx-click="leave_shop"
          class="w-full bg-gray-700 hover:bg-gray-600 active:scale-95 text-white font-bold text-xl py-4 rounded-2xl transition-all cursor-pointer shadow-lg"
        >
          Leave Shop →
        </button>
      </div>

      <%!-- Rest screen --%>
      <div :if={@phase == :rest} class="w-full max-w-lg" data-testid="rest-screen">
        <div class="bg-gray-800 rounded-2xl p-8 shadow-xl text-center space-y-6">
          <h2 class="text-3xl font-bold text-green-400">🏕 Rest Site</h2>
          <p class="text-gray-300 text-lg">
            You rest and recover. HP restored:
            <span class="text-green-400 font-bold">{rest_heal_amount(@player)}</span>
          </p>
          <div class="text-gray-400">
            HP: <span class="font-bold text-white">{@player.hp} / {@player.max_hp}</span>
          </div>
          <button
            phx-click="rest_and_continue"
            class="w-full bg-green-600 hover:bg-green-500 active:scale-95 text-white font-bold text-xl py-4 rounded-2xl transition-all cursor-pointer"
          >
            Continue →
          </button>
        </div>
      </div>

      <%!-- Game board (fighting + game_over) --%>
      <div :if={@phase in [:fighting, :game_over]} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center flex justify-center gap-3">
          <span class="bg-yellow-500 text-gray-950 font-bold text-base sm:text-2xl px-4 sm:px-6 py-1 sm:py-2 rounded-full">
            Floor {@current_floor + 1}
          </span>
          <span class="bg-gray-700 text-gray-200 font-bold text-base sm:text-2xl px-4 sm:px-6 py-1 sm:py-2 rounded-full">
            Turn {@turn}
          </span>
        </div>

        <%!-- Combatant cards --%>
        <div class="grid grid-cols-2 gap-2 sm:gap-6">
          <div class="bg-gray-800 rounded-2xl p-3 sm:p-6 shadow-xl flex flex-col items-center gap-1 sm:gap-3">
            <Portraits.player class="h-16 w-12 sm:h-36 sm:w-28 drop-shadow-lg" />
            <div class="w-full">
              <div class="text-xs sm:text-sm text-gray-400 uppercase tracking-widest">🧙 Player</div>
              <div class="text-base sm:text-3xl font-bold truncate" data-testid="player-name">
                {@player.name}
              </div>
              <div class="text-xs sm:text-lg text-gray-300 mt-1">
                HP: <span class="font-bold text-white">{@player.hp} / {@player.max_hp}</span>
              </div>
              <div class="w-full bg-gray-700 rounded-full h-2 sm:h-5 mt-2 overflow-hidden">
                <div
                  class="bg-green-500 h-2 sm:h-5 rounded-full transition-all duration-500"
                  style={"width: #{hp_pct(@player.hp, @player.max_hp)}%"}
                />
              </div>
              <div class="text-xs sm:text-sm text-gray-400 mt-1 sm:mt-2">
                🛡️ AC:
                <span class="text-white font-bold">{@player.armor_class + @player.bonus_ac}</span>
              </div>
              <div data-testid="player-energy" class="mt-2">
                <div class="text-xs text-gray-400 uppercase tracking-widest mb-1">⚡ Energy</div>
                <div class="flex gap-1.5">
                  <span
                    :for={i <- 1..@player.max_energy}
                    class={
                      if i <= @player.energy,
                        do: "text-yellow-400 text-2xl drop-shadow-[0_0_6px_#fbbf24]",
                        else: "text-gray-700 text-2xl"
                    }
                  >
                    ◆
                  </span>
                </div>
              </div>
              <div
                :if={@player.block > 0}
                data-testid="player-block"
                class="text-xs sm:text-sm text-gray-400 mt-0.5 sm:mt-1"
              >
                🛡 Block: <span class="text-blue-400 font-bold">{@player.block}</span>
              </div>
            </div>
          </div>

          <div class="bg-gray-800 rounded-2xl p-3 sm:p-6 shadow-xl flex flex-col items-center gap-1 sm:gap-3">
            <Portraits.monster name={@monster.name} class="h-16 w-16 sm:h-28 sm:w-28 drop-shadow-lg" />
            <div class="w-full">
              <div class="text-xs sm:text-sm text-gray-400 uppercase tracking-widest">👹 Monster</div>
              <div class="text-base sm:text-3xl font-bold truncate">{@monster.name}</div>
              <div class="text-xs sm:text-lg text-gray-300 mt-1">
                HP: <span class="font-bold text-white">{@monster.hp} / {@monster.max_hp}</span>
              </div>
              <div class="w-full bg-gray-700 rounded-full h-2 sm:h-5 mt-2 overflow-hidden">
                <div
                  class="bg-red-500 h-2 sm:h-5 rounded-full transition-all duration-500"
                  style={"width: #{hp_pct(@monster.hp, @monster.max_hp)}%"}
                />
              </div>
              <div class="text-xs sm:text-sm text-gray-400 mt-1 sm:mt-2">
                AC: <span class="text-white font-bold">{@monster.armor_class}</span>
              </div>
              <div
                :if={@phase == :fighting}
                class="mt-3 rounded-xl bg-yellow-950/60 border border-yellow-700/50 px-3 py-2 text-sm"
              >
                <span class="text-yellow-400 font-bold uppercase tracking-widest text-xs">
                  Next move
                </span>
                <div class="text-yellow-200 font-semibold mt-0.5">
                  {intent_icon(@monster.next_action.type)} {@monster.next_action.name}
                </div>
                <div class="text-orange-300 text-xs mt-0.5 font-mono">
                  {action_damage_text(@monster.next_action, @monster)}
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Combat log (collapsible) --%>
        <div class="bg-gray-800 rounded-2xl shadow-xl overflow-hidden">
          <button
            phx-click="toggle_log"
            class="w-full flex items-center justify-between px-4 py-3 text-gray-400 hover:text-gray-200 transition-colors cursor-pointer"
          >
            <span class="text-xs uppercase tracking-widest font-bold">
              📜 Combat Log
              <span
                :if={@log != []}
                class="ml-2 text-gray-600 normal-case tracking-normal font-normal"
              >
                ({length(@log)} entries)
              </span>
            </span>
            <span class="text-gray-500 text-sm">{if @show_log, do: "▲", else: "▼"}</span>
          </button>
          <div :if={@show_log} class="px-4 pb-4 space-y-1 border-t border-gray-700 pt-3">
            <p :for={entry <- @log} class="text-sm text-gray-200 leading-snug">
              › {entry}
            </p>
          </div>
        </div>

        <%!-- Card hand --%>
        <div :if={@phase == :fighting} class="space-y-3">
          <div class="flex flex-wrap gap-2 sm:gap-3 justify-center">
            <button
              :for={{card, i} <- Enum.with_index(@player.hand)}
              phx-click="play_card"
              phx-value-index={i}
              disabled={card.cost > @player.energy}
              class="bg-gray-800 border border-gray-600 hover:border-yellow-500 active:scale-95 text-white text-xs sm:text-sm py-3 px-3 rounded-2xl transition-all cursor-pointer shadow-lg disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100 flex flex-col items-center gap-1 min-w-[90px] max-w-[130px]"
            >
              <span class="text-yellow-400 text-lg">{card_icon(card.effect)}</span>
              <span class="text-white font-bold text-center leading-tight">{card.name}</span>
              <span class="text-gray-400 text-xs text-center leading-tight">{card.description}</span>
              <span class="text-yellow-300 text-xs font-bold mt-1">
                {if card.cost == 0, do: "Free", else: String.duplicate("◆", card.cost)}
              </span>
            </button>
          </div>
          <div class="flex gap-2 sm:gap-3 justify-center">
            <button
              phx-click="end_turn"
              class="bg-blue-700 hover:bg-blue-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 px-6 rounded-2xl transition-all cursor-pointer shadow-lg"
            >
              ⏭ End Turn
            </button>
            <button
              :if={@player.potions > 0}
              phx-click="use_potion"
              class="bg-emerald-700 hover:bg-emerald-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 px-6 rounded-2xl transition-all cursor-pointer shadow-lg"
            >
              🧪 Potion ({@player.potions})
            </button>
            <button
              phx-click="open_inventory"
              class="bg-purple-700 hover:bg-purple-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 px-6 rounded-2xl transition-all cursor-pointer shadow-lg"
            >
              🎒 Bag ({length(@player.inventory)})
            </button>
            <button
              phx-click="open_deck"
              class="bg-gray-700 hover:bg-gray-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 px-6 rounded-2xl transition-all cursor-pointer shadow-lg"
            >
              🃏 Deck
            </button>
          </div>
          <div class="text-center text-xs text-gray-600">
            Hand: {length(@player.hand)} · Draw: {length(@player.deck)} · Discard: {length(
              @player.discard
            )}
          </div>
        </div>
      </div>

      <%!-- Deck viewer --%>
      <div :if={@phase == :deck_view} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-gray-300">🃏 Your Cards</h2>
          <p class="text-gray-500 text-sm mt-1">
            Hand: {length(@player.hand)} · Draw: {length(@player.deck)} · Discard: {length(
              @player.discard
            )}
          </p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-6">
          <%!-- Hand --%>
          <div class="bg-gray-800 rounded-2xl p-4 shadow-xl">
            <div class="text-sm text-yellow-400 uppercase tracking-widest font-bold mb-3">
              Hand ({length(@player.hand)})
            </div>
            <div :if={@player.hand == []} class="text-gray-500 italic text-sm">Empty</div>
            <div class="space-y-2">
              <div
                :for={card <- @player.hand}
                class="flex items-center gap-2 bg-gray-700 rounded-xl px-3 py-2"
              >
                <span class="text-lg">{card_icon(card.effect)}</span>
                <div class="flex-1 min-w-0">
                  <div class="text-white font-bold text-sm truncate">{card.name}</div>
                  <div class="text-gray-400 text-xs truncate">{card.description}</div>
                </div>
                <span class="text-yellow-300 text-xs font-bold shrink-0">
                  {if card.cost == 0, do: "Free", else: String.duplicate("◆", card.cost)}
                </span>
              </div>
            </div>
          </div>
          <%!-- Draw pile --%>
          <div class="bg-gray-800 rounded-2xl p-4 shadow-xl">
            <div class="text-sm text-blue-400 uppercase tracking-widest font-bold mb-3">
              Draw pile ({length(@player.deck)})
            </div>
            <div :if={@player.deck == []} class="text-gray-500 italic text-sm">Empty</div>
            <div class="space-y-2">
              <div
                :for={card <- @player.deck}
                class="flex items-center gap-2 bg-gray-700 rounded-xl px-3 py-2"
              >
                <span class="text-lg">{card_icon(card.effect)}</span>
                <div class="flex-1 min-w-0">
                  <div class="text-white font-bold text-sm truncate">{card.name}</div>
                  <div class="text-gray-400 text-xs truncate">{card.description}</div>
                </div>
                <span class="text-yellow-300 text-xs font-bold shrink-0">
                  {if card.cost == 0, do: "Free", else: String.duplicate("◆", card.cost)}
                </span>
              </div>
            </div>
          </div>
          <%!-- Discard pile --%>
          <div class="bg-gray-800 rounded-2xl p-4 shadow-xl">
            <div class="text-sm text-gray-400 uppercase tracking-widest font-bold mb-3">
              Discard ({length(@player.discard)})
            </div>
            <div :if={@player.discard == []} class="text-gray-500 italic text-sm">Empty</div>
            <div class="space-y-2">
              <div
                :for={card <- @player.discard}
                class="flex items-center gap-2 bg-gray-700/60 rounded-xl px-3 py-2 opacity-70"
              >
                <span class="text-lg">{card_icon(card.effect)}</span>
                <div class="flex-1 min-w-0">
                  <div class="text-white font-bold text-sm truncate">{card.name}</div>
                  <div class="text-gray-400 text-xs truncate">{card.description}</div>
                </div>
                <span class="text-yellow-300 text-xs font-bold shrink-0">
                  {if card.cost == 0, do: "Free", else: String.duplicate("◆", card.cost)}
                </span>
              </div>
            </div>
          </div>
        </div>
        <button
          phx-click="close_deck"
          class="w-full bg-gray-700 hover:bg-gray-600 active:scale-95 text-white font-bold text-xl py-4 rounded-2xl transition-all cursor-pointer shadow-lg"
        >
          ⚔️ Back to Battle
        </button>
      </div>

      <%!-- Inventory screen --%>
      <div :if={@phase == :inventory} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-purple-400">🎒 Inventory</h2>
        </div>

        <%!-- Equipped items --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-6">
          <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
            <div class="text-sm text-gray-400 uppercase tracking-widest mb-3">⚔️ Weapon</div>
            <div :if={@player.equipped_weapon} class="flex items-center justify-between">
              <div class="text-lg font-bold text-white">
                {@player.equipped_weapon.name}
                <span class="text-green-400 ml-2">+{@player.equipped_weapon.bonus} damage</span>
              </div>
              <button
                phx-click="unequip_item"
                phx-value-slot="weapon"
                class="bg-gray-600 hover:bg-gray-500 active:scale-95 text-white font-bold text-sm px-3 py-1 rounded-lg transition-all cursor-pointer ml-3"
              >
                Unequip
              </button>
            </div>
            <div :if={!@player.equipped_weapon} class="text-gray-500 italic">None</div>
          </div>
          <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
            <div class="text-sm text-gray-400 uppercase tracking-widest mb-3">🪖 Helm</div>
            <div :if={@player.equipped_helm} class="flex items-center justify-between">
              <div class="text-lg font-bold text-white">
                {@player.equipped_helm.name}
                <span class="text-blue-400 ml-2">+{@player.equipped_helm.bonus} AC</span>
              </div>
              <button
                phx-click="unequip_item"
                phx-value-slot="helm"
                class="bg-gray-600 hover:bg-gray-500 active:scale-95 text-white font-bold text-sm px-3 py-1 rounded-lg transition-all cursor-pointer ml-3"
              >
                Unequip
              </button>
            </div>
            <div :if={!@player.equipped_helm} class="text-gray-500 italic">None</div>
          </div>
          <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
            <div class="text-sm text-gray-400 uppercase tracking-widest mb-3">🛡️ Body Armor</div>
            <div :if={@player.equipped_body} class="flex items-center justify-between">
              <div class="text-lg font-bold text-white">
                {@player.equipped_body.name}
                <span class="text-blue-400 ml-2">+{@player.equipped_body.bonus} AC</span>
              </div>
              <button
                phx-click="unequip_item"
                phx-value-slot="body"
                class="bg-gray-600 hover:bg-gray-500 active:scale-95 text-white font-bold text-sm px-3 py-1 rounded-lg transition-all cursor-pointer ml-3"
              >
                Unequip
              </button>
            </div>
            <div :if={!@player.equipped_body} class="text-gray-500 italic">None</div>
          </div>
          <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
            <div class="text-sm text-gray-400 uppercase tracking-widest mb-3">🥾 Boots</div>
            <div :if={@player.equipped_boots} class="flex items-center justify-between">
              <div class="text-lg font-bold text-white">
                {@player.equipped_boots.name}
                <span class="text-blue-400 ml-2">+{@player.equipped_boots.bonus} AC</span>
              </div>
              <button
                phx-click="unequip_item"
                phx-value-slot="boots"
                class="bg-gray-600 hover:bg-gray-500 active:scale-95 text-white font-bold text-sm px-3 py-1 rounded-lg transition-all cursor-pointer ml-3"
              >
                Unequip
              </button>
            </div>
            <div :if={!@player.equipped_boots} class="text-gray-500 italic">None</div>
          </div>
        </div>

        <%!-- Gold --%>
        <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
          <div data-testid="player-gold" class="text-sm text-gray-400 uppercase tracking-widest">
            🪙 Gold: <span class="text-yellow-400 font-bold text-base">{@player.gold}</span>
          </div>
        </div>

        <%!-- Unequipped items --%>
        <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
          <div class="text-sm text-gray-400 uppercase tracking-widest mb-4">Items in Bag</div>
          <div :if={Enum.empty?(@player.inventory)} class="text-gray-500 italic">
            Your bag is empty.
          </div>
          <div class="space-y-3">
            <div
              :for={{item, idx} <- Enum.with_index(@player.inventory)}
              class="flex items-center justify-between bg-gray-700 rounded-xl px-4 py-3"
            >
              <div>
                <span class="font-bold text-white">{item.name}</span>
                <span :if={item.type == :weapon} class="text-green-400 text-sm ml-2">
                  +{item.bonus} damage
                </span>
                <span :if={item.type != :weapon} class="text-blue-400 text-sm ml-2">
                  +{item.bonus} AC
                </span>
              </div>
              <button
                phx-click="equip_item"
                phx-value-index={idx}
                class="bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold text-sm px-4 py-2 rounded-lg transition-all cursor-pointer"
              >
                Equip
              </button>
            </div>
          </div>
        </div>

        <button
          phx-click="close_inventory"
          class="w-full bg-gray-700 hover:bg-gray-600 active:scale-95 text-white font-bold text-xl py-4 rounded-2xl transition-all cursor-pointer shadow-lg"
        >
          ⚔️ Back to Battle
        </button>
      </div>

      <%!-- Level-up card selection --%>
      <div :if={@phase == :reward} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-yellow-400">🏆 Room Cleared!</h2>
          <p class="text-base sm:text-xl text-gray-300 mt-2">Choose a card to add to your deck</p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-6">
          <div
            :for={card <- @upgrade_choices}
            class="bg-gray-800 rounded-2xl p-6 shadow-xl border border-gray-600 hover:border-yellow-500 transition-all flex flex-col"
          >
            <div class="text-4xl text-center mb-2">{card_icon(card.effect)}</div>
            <div class="text-lg font-bold text-yellow-400 text-center mb-1">{card.name}</div>
            <div class="text-xs text-gray-500 uppercase tracking-widest text-center mb-3">
              Cost: {if card.cost == 0, do: "Free", else: "#{card.cost} energy"}
            </div>
            <p class="text-gray-200 text-sm flex-1">{card.description}</p>
            <button
              phx-click="choose_upgrade"
              phx-value-id={card.id}
              class="mt-4 w-full bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold py-2 rounded-xl transition-all cursor-pointer"
            >
              Add to Deck
            </button>
          </div>
        </div>
        <div class="text-center">
          <button
            phx-click="skip_reward"
            class="text-gray-500 hover:text-gray-300 text-sm underline transition-colors cursor-pointer"
          >
            Skip — I don't need a card
          </button>
        </div>
      </div>

      <%!-- Elite loot screen --%>
      <div :if={@phase == :elite_loot} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-orange-400">☠️ Elite Spoils!</h2>
          <p class="text-base sm:text-xl text-gray-300 mt-2">Choose a reward from the fallen elite</p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-6">
          <div
            :for={{choice, idx} <- Enum.with_index(@elite_loot_choices)}
            class="bg-gray-800 rounded-2xl p-6 shadow-xl border border-gray-600 hover:border-orange-500 transition-all flex flex-col"
          >
            <div class="text-4xl text-center mb-2">
              {if match?({:item, _}, choice), do: "⚔️", else: "🧪"}
            </div>
            <div class="text-lg font-bold text-orange-400 text-center mb-1">
              {elite_choice_name(choice)}
            </div>
            <p class="text-gray-200 text-sm flex-1">{elite_choice_desc(choice)}</p>
            <button
              phx-click="choose_elite_loot"
              phx-value-index={idx}
              class="mt-4 w-full bg-orange-500 hover:bg-orange-400 active:scale-95 text-white font-bold py-2 rounded-xl transition-all cursor-pointer"
            >
              Take it
            </button>
          </div>
        </div>
        <div class="text-center">
          <button
            phx-click="skip_elite_loot"
            class="text-gray-500 hover:text-gray-300 text-sm underline transition-colors cursor-pointer"
          >
            Skip — leave the spoils behind
          </button>
        </div>
      </div>

      <%!-- Victory screen --%>
      <div :if={@phase == :victory} class="w-full max-w-lg text-center space-y-6">
        <div class="bg-yellow-950 border border-yellow-500 rounded-2xl p-8 shadow-xl">
          <h2 class="text-4xl sm:text-6xl font-bold text-yellow-400 mb-4">Victory!</h2>
          <p class="text-xl text-gray-300 mb-2">
            You defeated the dungeon boss!
          </p>
          <p class="text-gray-400">{@player.name}</p>
        </div>
        <button
          phx-click="play_again"
          class="bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold text-xl px-8 py-3 rounded-xl transition-all cursor-pointer"
        >
          Play Again
        </button>
      </div>

      <%!-- QR code fullscreen overlay --%>
      <div
        :if={@show_qr}
        phx-click="toggle_qr"
        class="fixed inset-0 z-50 bg-black/90 flex flex-col items-center justify-center cursor-pointer"
      >
        <p class="text-gray-400 text-sm mb-6 uppercase tracking-widest">Tap anywhere to close</p>
        <img
          src="https://api.qrserver.com/v1/create-qr-code/?data=https%3A%2F%2Fdnd-floral-paper-7223.fly.dev%2F&size=512x512&margin=2"
          alt="QR code for the game"
          class="w-72 h-72 sm:w-96 sm:h-96 rounded-2xl"
        />
        <p class="text-gray-300 text-lg mt-6 font-mono">dnd-floral-paper-7223.fly.dev</p>
      </div>

      <%!-- Fixed UI: QR button + GitHub link --%>
      <div class="fixed bottom-4 right-4 z-40">
        <button
          phx-click="toggle_qr"
          class="bg-gray-700 hover:bg-gray-600 active:scale-95 text-white text-sm font-bold px-3 py-2 rounded-xl transition-all cursor-pointer shadow-lg"
          title="Show QR code"
        >
          📱 QR
        </button>
      </div>
      <div class="fixed bottom-4 left-4 z-40">
        <a
          href="https://github.com/Cozidian/kode24"
          target="_blank"
          rel="noopener"
          class="text-gray-600 hover:text-gray-400 text-xs font-mono transition-colors"
        >
          github
        </a>
      </div>

      <%!-- Game over panel --%>
      <div
        :if={@phase == :game_over}
        class="mt-4 sm:mt-8 bg-red-950 border border-red-600 rounded-2xl p-4 sm:p-8 text-center w-full max-w-4xl"
      >
        <h2 class="text-3xl sm:text-5xl font-bold text-red-400 mb-3">Game Over</h2>
        <p class="text-base sm:text-2xl text-gray-300 mb-4 sm:mb-6">
          You reached floor <span class="font-bold text-yellow-400">{@current_floor + 1}</span>.
        </p>
        <GameComponents.highscore_list entries={@highscores} class="mt-6 mb-6" />
        <button
          phx-click="play_again"
          class="bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold text-xl px-8 py-3 rounded-xl transition-all cursor-pointer"
        >
          Play Again
        </button>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("toggle_qr", _params, socket) do
    {:noreply, assign(socket, show_qr: !socket.assigns.show_qr)}
  end

  @impl true
  def handle_event("toggle_log", _params, socket) do
    {:noreply, assign(socket, show_log: !socket.assigns.show_log)}
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    {:noreply,
     assign(socket,
       phase: :idle,
       player: nil,
       monster: nil,
       dungeon_map: nil,
       current_floor: 0,
       turn: 0,
       log: [],
       upgrade_choices: [],
       elite_loot_choices: [],
       post_elite_phase: :map,
       shop_inventory: [],
       pending_floor: 0,
       pending_name: nil,
       highscores: Highscore.list(),
       show_log: false
     )}
  end

  @impl true
  def handle_event("start_game", %{"username" => username}, socket) do
    {:noreply, assign(socket, phase: :class_select, pending_name: String.trim(username))}
  end

  @impl true
  def handle_event("choose_class", %{"class" => class_str}, socket) do
    class_id = String.to_atom(class_str)
    player = PlayerClass.new_player(class_id, socket.assigns.pending_name)
    dungeon_map = DungeonMap.generate()

    {:noreply,
     assign(socket,
       phase: :map,
       player: player,
       dungeon_map: dungeon_map,
       current_floor: 0,
       turn: 0,
       log: []
     )}
  end

  @impl true
  def handle_event("select_node", %{"node_id" => node_id}, socket) do
    %{dungeon_map: map, player: player} = socket.assigns
    node = map.nodes[node_id]
    map = DungeonMap.visit(map, node_id)

    case node.type do
      :rest ->
        healed_player = heal_player(player)

        {:noreply,
         assign(socket,
           phase: :rest,
           player: healed_player,
           dungeon_map: map,
           current_floor: node.floor
         )}

      :shop ->
        inventory = Shop.generate(player.class)

        {:noreply,
         assign(socket,
           phase: :shop,
           shop_inventory: inventory,
           dungeon_map: map,
           current_floor: node.floor
         )}

      :elite ->
        monster = Monster.elite_for_round(floor_to_round(node.floor))
        player = reset_for_new_fight(player)

        {:noreply,
         assign(socket,
           phase: :fighting,
           player: player,
           monster: monster,
           dungeon_map: map,
           current_floor: node.floor,
           turn: 0,
           log: ["⚠️ An elite #{monster.name} blocks your path!"]
         )}

      fight_type when fight_type in [:fight, :boss] ->
        monster = Monster.for_round(floor_to_round(node.floor))
        player = reset_for_new_fight(player)

        {:noreply,
         assign(socket,
           phase: :fighting,
           player: player,
           monster: monster,
           dungeon_map: map,
           current_floor: node.floor,
           turn: 0,
           log: ["A wild #{monster.name} appears!"]
         )}
    end
  end

  @impl true
  def handle_event("rest_and_continue", _params, socket) do
    {:noreply, assign(socket, phase: :map)}
  end

  @impl true
  def handle_event("play_card", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)

    %{player: player, monster: monster, current_floor: floor, log: log} = socket.assigns

    with card when not is_nil(card) <- Enum.at(player.hand, idx),
         {:alive, new_player, new_monster, entries} <-
           Combat.play_card(player, monster, card, &:rand.uniform/1, idx) do
      {:noreply,
       socket
       |> assign(player: new_player, monster: new_monster)
       |> put_log(log, entries)}
    else
      nil ->
        {:noreply, socket}

      {:monster_dead, new_player, _dead_monster, entries} ->
        handle_monster_dead(socket, player, new_player, floor, log, entries)
    end
  end

  @impl true
  def handle_event("end_turn", _params, socket) do
    %{player: player, monster: monster, current_floor: floor, turn: turn, log: log} =
      socket.assigns

    case Combat.end_turn(player, monster) do
      {:continue, new_player, new_monster, entries} ->
        new_monster = %{new_monster | next_action: Monster.pick_action(new_monster.actions)}

        {:noreply,
         socket
         |> assign(player: new_player, monster: new_monster, turn: turn + 1)
         |> put_log(log, entries)}

      {:player_dead, new_player, new_monster, entries} ->
        highscores = Highscore.add(new_player.name, floor + 1)

        {:noreply,
         socket
         |> assign(
           phase: :game_over,
           player: new_player,
           monster: new_monster,
           turn: turn + 1,
           highscores: highscores
         )
         |> put_log(log, entries)}
    end
  end

  @impl true
  def handle_event("use_potion", _params, socket) do
    player = socket.assigns.player

    if player.potions > 0 do
      amount = :rand.uniform(4) + :rand.uniform(4)

      new_player = %{
        player
        | hp: min(player.max_hp, player.hp + amount),
          potions: player.potions - 1
      }

      {:noreply,
       socket
       |> assign(player: new_player)
       |> put_log(socket.assigns.log, ["You drink a potion and recover #{amount} HP!"])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("choose_upgrade", %{"id" => id_str}, socket) do
    player = socket.assigns.player
    card = Enum.find(Card.all(player.class), &(to_string(&1.id) == id_str))
    after_phase = Map.get(socket.assigns, :pending_phase, :map)

    player =
      if card,
        do: %{player | discard: [card | player.discard]},
        else: player

    socket = assign(socket, player: player, upgrade_choices: [])

    socket =
      case after_phase do
        :elite_loot -> assign(socket, phase: :elite_loot)
        :victory -> assign(socket, phase: :victory)
        _ -> assign(socket, phase: :map)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("skip_reward", _params, socket) do
    after_phase = Map.get(socket.assigns, :pending_phase, :map)

    socket =
      case after_phase do
        :elite_loot -> assign(socket, phase: :elite_loot, upgrade_choices: [])
        :victory -> assign(socket, phase: :victory, upgrade_choices: [])
        _ -> assign(socket, phase: :map, upgrade_choices: [])
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("choose_elite_loot", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    player = socket.assigns.player
    choice = Enum.at(socket.assigns.elite_loot_choices, idx)
    after_phase = socket.assigns.post_elite_phase

    player =
      case choice do
        {:item, item} -> %{player | inventory: [item | player.inventory]}
        {:potion, n} -> %{player | potions: player.potions + n}
        nil -> player
      end

    {:noreply, assign(socket, player: player, elite_loot_choices: [], phase: after_phase)}
  end

  @impl true
  def handle_event("skip_elite_loot", _params, socket) do
    {:noreply, assign(socket, elite_loot_choices: [], phase: socket.assigns.post_elite_phase)}
  end

  @impl true
  def handle_event("buy_item", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    player = socket.assigns.player
    inventory = socket.assigns.shop_inventory
    entry = Enum.at(inventory, idx)

    case entry do
      {_type, _payload, price} when player.gold < price ->
        {:noreply, socket}

      {:item, item, price} ->
        player = %{player | gold: player.gold - price, inventory: [item | player.inventory]}
        {:noreply, assign(socket, player: player, shop_inventory: List.delete_at(inventory, idx))}

      {:potion, count, price} ->
        player = %{player | gold: player.gold - price, potions: player.potions + count}
        {:noreply, assign(socket, player: player, shop_inventory: List.delete_at(inventory, idx))}

      {:card, card, price} ->
        player = %{player | gold: player.gold - price, discard: [card | player.discard]}
        {:noreply, assign(socket, player: player, shop_inventory: List.delete_at(inventory, idx))}

      nil ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("leave_shop", _params, socket) do
    {:noreply, assign(socket, phase: :map, shop_inventory: [])}
  end

  @impl true
  def handle_event("open_inventory", _params, socket) do
    {:noreply, assign(socket, phase: :inventory)}
  end

  @impl true
  def handle_event("close_inventory", _params, socket) do
    {:noreply, assign(socket, phase: :fighting)}
  end

  @impl true
  def handle_event("open_deck", _params, socket) do
    {:noreply, assign(socket, phase: :deck_view)}
  end

  @impl true
  def handle_event("close_deck", _params, socket) do
    {:noreply, assign(socket, phase: :fighting)}
  end

  @impl true
  def handle_event("unequip_item", %{"slot" => slot}, socket) do
    player = Player.unequip(socket.assigns.player, String.to_atom(slot))
    {:noreply, assign(socket, player: player)}
  end

  @impl true
  def handle_event("equip_item", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    player = socket.assigns.player
    item = Enum.at(player.inventory, idx)
    player = player |> Map.update!(:inventory, &List.delete_at(&1, idx)) |> Player.equip(item)
    {:noreply, assign(socket, player: player)}
  end

  if Mix.env() == :test do
    @impl true
    def handle_event("__test_set_monster_hp", %{"hp" => hp_str}, socket) do
      monster = %{socket.assigns.monster | hp: String.to_integer(hp_str), armor_class: 1}
      {:noreply, assign(socket, monster: monster)}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp handle_monster_dead(socket, _old_player, new_player, floor, log, entries) do
    current_node = DungeonMap.current_node(socket.assigns.dungeon_map)
    is_boss = current_node.type == :boss
    is_elite = current_node.type == :elite
    final_phase = if is_boss, do: :victory, else: :map
    card_choices = Card.reward_pool(new_player.class) |> Enum.shuffle() |> Enum.take(3)

    {pending_phase, extra_assigns} =
      if is_elite do
        loot_choices = Loot.elite_choices()
        {:elite_loot, [elite_loot_choices: loot_choices, post_elite_phase: final_phase]}
      else
        {final_phase, []}
      end

    {:noreply,
     socket
     |> assign(
       [
         phase: :reward,
         player: new_player,
         upgrade_choices: card_choices,
         pending_floor: floor,
         pending_phase: pending_phase
       ] ++ extra_assigns
     )
     |> put_log(log, entries ++ ["Room cleared! Choose your reward."])}
  end

  defp put_log(socket, current, new_entries) do
    log = (current ++ new_entries) |> Enum.take(-5)
    assign(socket, log: log)
  end

  defp hp_pct(_hp, 0), do: 0
  defp hp_pct(hp, max_hp), do: trunc(hp / max_hp * 100)

  # Map floor (0–5) to a monster round for scaling
  # Floor 0→1, 1→3, 2→5, 3→7, 4→9, 5(boss)→11
  defp floor_to_round(floor), do: floor * 2 + 1

  # Heal player by 30% of max_hp, capped at max_hp
  defp heal_player(%{hp: hp, max_hp: max_hp} = player) do
    heal = max(1, trunc(max_hp * 0.3))
    %{player | hp: min(max_hp, hp + heal)}
  end

  defp rest_heal_amount(%{max_hp: max_hp}), do: max(1, trunc(max_hp * 0.3))

  defp shop_entry_icon({:item, %{type: :weapon}, _}), do: "⚔️"
  defp shop_entry_icon({:item, %{type: :armor}, _}), do: "🛡️"
  defp shop_entry_icon({:item, %{type: :helm}, _}), do: "🪖"
  defp shop_entry_icon({:item, %{type: :boots}, _}), do: "🥾"
  defp shop_entry_icon({:potion, _, _}), do: "🧪"
  defp shop_entry_icon({:card, _, _}), do: "🃏"

  defp shop_entry_name({:item, item, _}), do: item.name
  defp shop_entry_name({:potion, count, _}), do: "#{count}× Potion"
  defp shop_entry_name({:card, card, _}), do: card.name

  defp shop_entry_desc({:item, %{type: :weapon, bonus: b}, _}), do: "+#{b} damage"
  defp shop_entry_desc({:item, %{type: type, bonus: b}, _}), do: "+#{b} AC (#{type})"
  defp shop_entry_desc({:potion, _, _}), do: "Restore HP in battle"
  defp shop_entry_desc({:card, card, _}), do: card.description

  defp elite_choice_name({:item, item}), do: item.name
  defp elite_choice_name({:potion, n}), do: "#{n}x Potion"

  defp elite_choice_desc({:item, %{type: :weapon, bonus: b}}), do: "+#{b} damage weapon"
  defp elite_choice_desc({:item, %{type: type, bonus: b}}), do: "+#{b} AC #{type}"
  defp elite_choice_desc({:potion, n}), do: "Restore HP #{n} times in battle"

  defp reset_for_new_fight(player) do
    all_cards = player.hand ++ player.deck ++ player.discard
    {hand, deck} = all_cards |> Enum.shuffle() |> Enum.split(5)

    %{
      player
      | hand: hand,
        deck: deck,
        discard: [],
        energy: player.max_energy,
        block: 0,
        dodge_next: false
    }
  end
end
