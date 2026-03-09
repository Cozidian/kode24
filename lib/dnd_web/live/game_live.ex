defmodule DndWeb.GameLive do
  use DndWeb, :live_view

  alias DungeonGame.{Combat, Monster, Player}
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
        round: 0,
        turn: 0,
        log: []
      )

    {:ok, socket, layout: false}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-gray-100 flex flex-col items-center justify-center p-8 font-mono select-none">
      <h1 class="text-6xl font-bold mb-10 text-yellow-400 tracking-tight">⚔ Dungeon Crawler</h1>

      <%!-- Idle state --%>
      <div :if={@phase == :idle} class="bg-gray-800 rounded-2xl p-12 text-center shadow-2xl w-full max-w-lg">
        <Portraits.player class="w-32 h-40 mx-auto mb-6 drop-shadow-lg" />
        <p class="text-2xl text-gray-300 mb-8">
          Brave adventurer, do you dare enter the dungeon?
        </p>
        <button
          phx-click="start_game"
          class="bg-yellow-500 hover:bg-yellow-400 active:scale-95 text-gray-950 font-bold text-2xl px-10 py-4 rounded-xl transition-all cursor-pointer"
        >
          Start Game
        </button>
      </div>

      <%!-- Game board (fighting + game_over) --%>
      <div :if={@phase in [:fighting, :game_over]} class="w-full max-w-4xl space-y-6">
        <div class="text-center flex justify-center gap-4">
          <span class="bg-yellow-500 text-gray-950 font-bold text-2xl px-6 py-2 rounded-full">
            Round {@round}
          </span>
          <span class="bg-gray-700 text-gray-200 font-bold text-2xl px-6 py-2 rounded-full">
            Turn {@turn}
          </span>
        </div>

        <%!-- Combatant cards --%>
        <div class="grid grid-cols-2 gap-6">
          <div class="bg-gray-800 rounded-2xl p-6 shadow-xl flex flex-col items-center gap-3">
            <Portraits.player class="h-36 w-28 drop-shadow-lg" />
            <div class="w-full">
              <div class="text-sm text-gray-400 uppercase tracking-widest">🧙 Player</div>
              <div class="text-3xl font-bold">{@player.name}</div>
              <div class="text-lg text-gray-300 mt-1">
                HP: <span class="font-bold text-white">{@player.hp} / {@player.max_hp}</span>
              </div>
              <div class="w-full bg-gray-700 rounded-full h-5 mt-2 overflow-hidden">
                <div
                  class="bg-green-500 h-5 rounded-full transition-all duration-500"
                  style={"width: #{hp_pct(@player.hp, @player.max_hp)}%"}
                />
              </div>
              <div class="text-sm text-gray-400 mt-2">
                🧪 Potions: <span class="text-white font-bold">{@player.potions}</span>
              </div>
            </div>
          </div>

          <div class="bg-gray-800 rounded-2xl p-6 shadow-xl flex flex-col items-center gap-3">
            <Portraits.monster name={@monster.name} class="h-28 w-28 drop-shadow-lg" />
            <div class="w-full">
              <div class="text-sm text-gray-400 uppercase tracking-widest">👹 Monster</div>
              <div class="text-3xl font-bold">{@monster.name}</div>
              <div class="text-lg text-gray-300 mt-1">
                HP: <span class="font-bold text-white">{@monster.hp} / {@monster.max_hp}</span>
              </div>
              <div class="w-full bg-gray-700 rounded-full h-5 mt-2 overflow-hidden">
                <div
                  class="bg-red-500 h-5 rounded-full transition-all duration-500"
                  style={"width: #{hp_pct(@monster.hp, @monster.max_hp)}%"}
                />
              </div>
              <div class="text-sm text-gray-400 mt-2">
                AC: <span class="text-white font-bold">{@monster.armor_class}</span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Combat log --%>
        <div class="bg-gray-800 rounded-2xl p-6 shadow-xl">
          <div class="text-sm text-gray-400 uppercase tracking-widest mb-4">Combat Log</div>
          <div class="space-y-2 min-h-32">
            <p :for={entry <- @log} class="text-lg text-gray-200 leading-snug">
              › {entry}
            </p>
          </div>
        </div>

        <%!-- Player action buttons --%>
        <div :if={@phase == :fighting} class="grid grid-cols-3 gap-4">
          <button
            phx-click="player_action"
            phx-value-action="attack"
            class="bg-red-700 hover:bg-red-600 active:scale-95 text-white font-bold text-xl py-5 rounded-2xl transition-all cursor-pointer shadow-lg"
          >
            ⚔️ Attack
          </button>
          <button
            phx-click="player_action"
            phx-value-action="defend"
            class="bg-blue-700 hover:bg-blue-600 active:scale-95 text-white font-bold text-xl py-5 rounded-2xl transition-all cursor-pointer shadow-lg"
          >
            🛡️ Defend
          </button>
          <button
            phx-click="player_action"
            phx-value-action="heal"
            disabled={@player.potions == 0}
            class="bg-emerald-700 hover:bg-emerald-600 active:scale-95 text-white font-bold text-xl py-5 rounded-2xl transition-all cursor-pointer shadow-lg disabled:opacity-40 disabled:cursor-not-allowed disabled:active:scale-100"
          >
            🧪 Heal ({@player.potions})
          </button>
        </div>
      </div>

      <%!-- Game over panel --%>
      <div
        :if={@phase == :game_over}
        class="mt-8 bg-red-950 border border-red-600 rounded-2xl p-8 text-center w-full max-w-4xl"
      >
        <h2 class="text-5xl font-bold text-red-400 mb-3">Game Over</h2>
        <p class="text-2xl text-gray-300 mb-6">
          You survived <span class="font-bold text-yellow-400">{@round}</span> round(s).
        </p>
        <button
          phx-click="start_game"
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
  def handle_event("start_game", _params, socket) do
    player = %Player{}
    round = 1
    monster = Monster.for_round(round)

    socket =
      assign(socket,
        phase: :fighting,
        player: player,
        monster: monster,
        round: round,
        turn: 0,
        log: ["A wild #{monster.name} appears!"]
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("player_action", %{"action" => action_str}, socket) do
    action = String.to_atom(action_str)
    %{player: player, monster: monster, round: round, turn: turn, log: log} = socket.assigns
    next_turn = turn + 1

    case Combat.tick(player, monster, action) do
      {:continue, player, monster, entries} ->
        {:noreply, socket |> assign(player: player, monster: monster, turn: next_turn) |> put_log(log, entries)}

      {:monster_dead, player, _dead_monster, entries} ->
        next_round = round + 1
        next_monster = Monster.for_round(next_round)
        announce = "Round #{next_round}: A #{next_monster.name} appears!"

        socket =
          socket
          |> assign(player: player, monster: next_monster, round: next_round, turn: 0)
          |> put_log(log, entries ++ [announce])

        {:noreply, socket}

      {:player_dead, player, monster, entries} ->
        socket =
          socket
          |> assign(phase: :game_over, player: player, monster: monster, turn: next_turn)
          |> put_log(log, entries)

        {:noreply, socket}
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
end
