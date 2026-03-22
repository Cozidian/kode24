defmodule DndWeb.GameLive do
  use DndWeb, :live_view

  alias DungeonGame.{Combat, DungeonMap, Highscore, Monster, Player, Upgrade}
  alias DndWeb.Portraits

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
        pending_floor: 0,
        highscores: Highscore.list(),
        show_qr: false
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
        <.highscore_list entries={@highscores} class="mb-8 w-full" />
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
          <.dungeon_map_svg map={@dungeon_map} />
        </div>

        <p class="text-center text-gray-500 text-sm">Select a node to continue your journey</p>
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
              <div data-testid="player-level" class="text-xs sm:text-sm text-gray-400 mt-0.5 sm:mt-1">
                ⭐ Lvl: <span class="text-yellow-400 font-bold">{@player.level}</span>
              </div>
              <div data-testid="player-xp" class="text-xs sm:text-sm text-gray-400 mt-0.5 sm:mt-1">
                ✨ XP: <span class="text-yellow-400 font-bold">{@player.xp}</span>
                <span class="text-gray-500 hidden sm:inline ml-1">
                  ({xp_to_next(@player)} to next)
                </span>
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
              <div data-testid="monster-xp" class="text-xs sm:text-sm text-gray-400 mt-0.5 sm:mt-1">
                ✨ XP: <span class="text-yellow-400 font-bold">{@monster.xp}</span>
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
              </div>
            </div>
          </div>
        </div>

        <%!-- Combat log --%>
        <div class="bg-gray-800 rounded-2xl p-3 sm:p-6 shadow-xl">
          <div class="text-xs sm:text-sm text-gray-400 uppercase tracking-widest mb-2 sm:mb-4">
            Combat Log
          </div>
          <div class="space-y-1 sm:space-y-2 min-h-20 sm:min-h-32">
            <p :for={entry <- @log} class="text-sm sm:text-lg text-gray-200 leading-snug">
              › {entry}
            </p>
          </div>
        </div>

        <%!-- Action buttons --%>
        <div :if={@phase == :fighting} class="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-4">
          <button
            phx-click="player_action"
            phx-value-action="attack"
            class="bg-red-700 hover:bg-red-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 sm:py-5 rounded-2xl transition-all cursor-pointer shadow-lg"
          >
            ⚔️ Attack ({damage_label(@player)})
          </button>
          <button
            phx-click="player_action"
            phx-value-action="defend"
            class="bg-blue-700 hover:bg-blue-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 sm:py-5 rounded-2xl transition-all cursor-pointer shadow-lg"
          >
            🛡️ Defend
          </button>
          <button
            phx-click="player_action"
            phx-value-action="heal"
            disabled={@player.potions == 0}
            class="bg-emerald-700 hover:bg-emerald-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 sm:py-5 rounded-2xl transition-all cursor-pointer shadow-lg disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100"
          >
            🧪 Heal ({@player.potions})
          </button>
          <button
            phx-click="open_inventory"
            class="bg-purple-700 hover:bg-purple-600 active:scale-95 text-white font-bold text-sm sm:text-xl py-4 sm:py-5 rounded-2xl transition-all cursor-pointer shadow-lg"
          >
            🎒 Bag ({length(@player.inventory)})
          </button>
        </div>
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

      <%!-- Level-up upgrade selection --%>
      <div :if={@phase == :level_up} class="w-full max-w-4xl space-y-3 sm:space-y-6">
        <div class="text-center">
          <h2 class="text-2xl sm:text-4xl font-bold text-yellow-400">⭐ Level Up!</h2>
          <p class="text-base sm:text-xl text-gray-300 mt-2">Choose an upgrade</p>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 sm:gap-6">
          <div
            :for={upgrade <- @upgrade_choices}
            class="bg-gray-800 rounded-2xl p-6 shadow-xl border border-gray-600 hover:border-yellow-500 transition-all flex flex-col"
          >
            <div class="text-lg font-bold text-yellow-400 mb-1">
              {upgrade_type_icon(upgrade.type)} {upgrade.name}
            </div>
            <div class="text-xs text-gray-500 uppercase tracking-widest mb-3">{upgrade.type}</div>
            <p class="text-gray-200 text-sm flex-1">{upgrade.description}</p>
            <button
              phx-click="choose_upgrade"
              phx-value-id={upgrade.id}
              class="mt-4 w-full bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold py-2 rounded-xl transition-all cursor-pointer"
            >
              Choose
            </button>
          </div>
        </div>
      </div>

      <%!-- Victory screen --%>
      <div :if={@phase == :victory} class="w-full max-w-lg text-center space-y-6">
        <div class="bg-yellow-950 border border-yellow-500 rounded-2xl p-8 shadow-xl">
          <h2 class="text-4xl sm:text-6xl font-bold text-yellow-400 mb-4">Victory!</h2>
          <p class="text-xl text-gray-300 mb-2">
            You defeated the dungeon boss!
          </p>
          <p class="text-gray-400">
            {@player.name} — Level <span class="text-yellow-400 font-bold">{@player.level}</span>
            — XP <span class="text-yellow-400 font-bold">{@player.xp}</span>
          </p>
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
        <.highscore_list entries={@highscores} class="mt-6 mb-6" />
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
  # Components
  # ---------------------------------------------------------------------------

  attr :entries, :list, required: true
  attr :class, :string, default: nil

  defp highscore_list(assigns) do
    ~H"""
    <div data-testid="highscore-list" class={"text-left #{@class}"}>
      <h3 class="text-lg font-bold text-yellow-400 mb-3 text-center tracking-widest uppercase">
        Hall of Fame
      </h3>
      <p :if={@entries == []} class="text-center text-gray-500 text-sm">No scores yet.</p>
      <ol :if={@entries != []} class="space-y-1">
        <li
          :for={{entry, i} <- Enum.with_index(@entries, 1)}
          class="flex justify-between text-gray-300 text-sm px-2 py-1 rounded bg-gray-700"
        >
          <span>{i}. {entry.name}</span>
          <span class="text-yellow-400">{entry.rounds} rounds</span>
        </li>
      </ol>
    </div>
    """
  end

  attr :map, DungeonMap, required: true

  defp dungeon_map_svg(assigns) do
    assigns =
      assign(assigns,
        available_ids:
          assigns.map |> DungeonMap.available_nodes() |> Enum.map(& &1.id) |> MapSet.new()
      )

    ~H"""
    <svg
      viewBox="0 0 400 520"
      xmlns="http://www.w3.org/2000/svg"
      class="w-full max-w-sm mx-auto"
      aria-label="Dungeon map"
    >
      <%!-- Connection lines --%>
      <%= for node <- Map.values(@map.nodes), conn_id <- node.connections do %>
        <% target = @map.nodes[conn_id] %>
        <line
          x1={node_x(node)}
          y1={node_y(node)}
          x2={node_x(target)}
          y2={node_y(target)}
          stroke="#4b5563"
          stroke-width="2"
        />
      <% end %>

      <%!-- Nodes --%>
      <%= for node <- nodes_bottom_to_top(@map) do %>
        <% available = MapSet.member?(@available_ids, node.id) %>
        <% visited = node.id in @map.visited_ids %>
        <% current = node.id == @map.current_node_id %>
        <g
          data-testid="map-node"
          data-node-type={node.type}
          data-available={available}
          phx-click={if available, do: "select_node"}
          phx-value-node_id={if available, do: node.id}
          class={if available, do: "cursor-pointer", else: ""}
          transform={"translate(#{node_x(node)}, #{node_y(node)})"}
        >
          <circle
            r="22"
            fill={node_fill(node.type, available, visited)}
            stroke={if current, do: "#fbbf24", else: node_stroke(node.type, available)}
            stroke-width={if current, do: "4", else: "2"}
            opacity={if visited and not current, do: "0.4", else: "1"}
          />
          <text
            text-anchor="middle"
            dominant-baseline="central"
            font-size="16"
            opacity={if visited and not current, do: "0.4", else: "1"}
          >
            {node_icon(node.type)}
          </text>
        </g>
      <% end %>
    </svg>
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
       pending_floor: 0,
       highscores: Highscore.list()
     )}
  end

  @impl true
  def handle_event("start_game", %{"username" => username}, socket) do
    player = %Player{name: String.trim(username)}
    dungeon_map = DungeonMap.generate()

    socket =
      assign(socket,
        phase: :map,
        player: player,
        dungeon_map: dungeon_map,
        current_floor: 0,
        turn: 0,
        log: []
      )

    {:noreply, socket}
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

      fight_type when fight_type in [:fight, :boss] ->
        monster = Monster.for_round(floor_to_round(node.floor))

        {:noreply,
         assign(socket,
           phase: :fighting,
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
  def handle_event("player_action", %{"action" => action_str}, socket) do
    action = String.to_atom(action_str)

    %{player: player, monster: monster, current_floor: floor, turn: turn, log: log} =
      socket.assigns

    case Combat.tick(player, monster, action) do
      {:continue, new_player, new_monster, entries} ->
        new_monster = %{new_monster | next_action: Monster.pick_action(new_monster.actions)}

        {:noreply,
         socket
         |> assign(player: new_player, monster: new_monster, turn: turn + 1)
         |> put_log(log, entries)}

      {:monster_dead, new_player, _dead_monster, entries} ->
        current_node = DungeonMap.current_node(socket.assigns.dungeon_map)

        if new_player.level > player.level do
          choices = Upgrade.random_choices(new_player, 3)
          after_fight_phase = if current_node.type == :boss, do: :victory, else: :map

          {:noreply,
           socket
           |> assign(
             phase: :level_up,
             player: new_player,
             upgrade_choices: choices,
             pending_floor: floor,
             pending_phase: after_fight_phase
           )
           |> put_log(log, entries ++ ["⭐ Level #{new_player.level}! Choose an upgrade!"])}
        else
          if current_node.type == :boss do
            {:noreply,
             socket
             |> assign(phase: :victory, player: new_player)
             |> put_log(log, entries ++ ["🎉 You defeated the boss!"])}
          else
            {:noreply,
             socket
             |> assign(phase: :map, player: new_player, monster: nil)
             |> put_log(log, entries)}
          end
        end

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
  def handle_event("choose_upgrade", %{"id" => id_str}, socket) do
    upgrade = Enum.find(Upgrade.all(), &(to_string(&1.id) == id_str))
    player = Upgrade.apply(socket.assigns.player, upgrade)
    after_phase = Map.get(socket.assigns, :pending_phase, :map)

    socket = assign(socket, player: player, upgrade_choices: [])

    socket =
      if after_phase == :victory do
        assign(socket, phase: :victory)
      else
        assign(socket, phase: :map)
      end

    {:noreply, socket}
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

  defp put_log(socket, current, new_entries) do
    log = (current ++ new_entries) |> Enum.take(-5)
    assign(socket, log: log)
  end

  defp hp_pct(_hp, 0), do: 0
  defp hp_pct(hp, max_hp), do: trunc(hp / max_hp * 100)

  defp damage_label(%{damage: dice, bonus_damage: 0}), do: dice
  defp damage_label(%{damage: dice, bonus_damage: bonus}), do: "(#{dice})+#{bonus}"

  defp xp_to_next(%{level: level, xp: xp}) do
    max(0, Player.xp_threshold(level + 1) - xp)
  end

  defp upgrade_type_icon(:attack), do: "⚔️"
  defp upgrade_type_icon(:defend), do: "🛡️"
  defp upgrade_type_icon(:heal), do: "🧪"
  defp upgrade_type_icon(:passive), do: "✨"

  defp intent_icon(:attack), do: "⚔️"
  defp intent_icon(:heavy_attack), do: "💥"
  defp intent_icon(:ranged), do: "🏹"
  defp intent_icon(:heal), do: "💚"
  defp intent_icon(:steal_potion), do: "🪙"

  # Map floor (0–5) to a monster round for scaling
  # Floor 0→1, 1→3, 2→5, 3→7, 4→9, 5(boss)→11
  defp floor_to_round(floor), do: floor * 2 + 1

  # Heal player by 30% of max_hp, capped at max_hp
  defp heal_player(%{hp: hp, max_hp: max_hp} = player) do
    heal = max(1, trunc(max_hp * 0.3))
    %{player | hp: min(max_hp, hp + heal)}
  end

  defp rest_heal_amount(%{max_hp: max_hp}), do: max(1, trunc(max_hp * 0.3))

  # SVG layout helpers — floor 5 (boss) at top (y=40), floor 0 at bottom (y=480)
  # Each floor is spaced 80px apart.
  defp node_y(%{floor: floor}), do: 480 - floor * 80
  defp node_x(%{floor: 5}), do: 200
  defp node_x(%{position: pos}), do: 80 + pos * 120

  defp nodes_bottom_to_top(%{nodes: nodes}) do
    nodes |> Map.values() |> Enum.sort_by(& &1.floor)
  end

  defp node_fill(:boss, true, _), do: "#7c3aed"
  defp node_fill(:boss, _, _), do: "#4c1d95"
  defp node_fill(:fight, true, _), do: "#b91c1c"
  defp node_fill(:fight, _, _), do: "#7f1d1d"
  defp node_fill(:rest, true, _), do: "#15803d"
  defp node_fill(:rest, _, _), do: "#14532d"

  defp node_stroke(:boss, true), do: "#a78bfa"
  defp node_stroke(:boss, _), do: "#7c3aed"
  defp node_stroke(:fight, true), do: "#ef4444"
  defp node_stroke(:fight, _), do: "#b91c1c"
  defp node_stroke(:rest, true), do: "#4ade80"
  defp node_stroke(:rest, _), do: "#16a34a"

  defp node_icon(:boss), do: "💀"
  defp node_icon(:fight), do: "⚔"
  defp node_icon(:rest), do: "🏕"
end
