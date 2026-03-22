defmodule DndWeb.GameComponents do
  @moduledoc """
  Reusable UI components and rendering helpers for GameLive.

  Includes:
  - `highscore_list/1` — Hall of Fame leaderboard
  - `dungeon_map_svg/1` — interactive SVG map
  - Icon/text helpers: `card_icon/1`, `intent_icon/1`, `action_damage_text/2`
  - SVG layout helpers: `node_x/1`, `node_y/1`, `node_fill/3`, `node_stroke/2`, `node_icon/1`
  """

  use Phoenix.Component

  alias DungeonGame.DungeonMap

  # ---------------------------------------------------------------------------
  # Highscore list
  # ---------------------------------------------------------------------------

  attr :entries, :list, required: true
  attr :class, :string, default: nil

  def highscore_list(assigns) do
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

  # ---------------------------------------------------------------------------
  # Dungeon map SVG
  # ---------------------------------------------------------------------------

  attr :map, DungeonMap, required: true

  def dungeon_map_svg(assigns) do
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
  # Icon/text helpers (used by game_live.ex render and templates)
  # ---------------------------------------------------------------------------

  def card_icon({:damage, _}), do: "⚔️"
  def card_icon({:damage_nac, _}), do: "✨"
  def card_icon({:block, _}), do: "🛡"
  def card_icon({:damage_and_block, _, _}), do: "⚔🛡"
  def card_icon({:multi_hit, _, _}), do: "💥"
  def card_icon(:shield_slam), do: "🗡"
  def card_icon({:draw, _}), do: "📜"
  def card_icon(:dodge), do: "👤"
  def card_icon({:damage_and_draw, _, _}), do: "⚔📜"
  def card_icon({:dodge_and_draw, _}), do: "👤📜"
  def card_icon({:block_and_draw, _, _}), do: "🛡📜"
  def card_icon({:damage_nac_and_draw, _, _}), do: "✨📜"
  def card_icon(_), do: "🃏"

  def intent_icon(:attack), do: "⚔️"
  def intent_icon(:heavy_attack), do: "💥"
  def intent_icon(:ranged), do: "🏹"
  def intent_icon(:heal), do: "💚"
  def intent_icon(:steal_potion), do: "🪙"

  def action_damage_text(%{type: :attack}, monster), do: monster.damage
  def action_damage_text(%{type: :heavy_attack} = action, _), do: action.damage
  def action_damage_text(%{type: :ranged} = action, _), do: action.damage
  def action_damage_text(%{type: :heal} = action, _), do: "heals #{action.amount}"
  def action_damage_text(%{type: :steal_potion}, _), do: "steals a potion"
  def action_damage_text(_, _), do: ""

  # ---------------------------------------------------------------------------
  # SVG layout helpers
  # ---------------------------------------------------------------------------

  # Floor 5 (boss) at top (y=40), floor 0 at bottom (y=480); 80px per floor.
  def node_y(%{floor: floor}), do: 480 - floor * 80
  def node_x(%{floor: 5}), do: 200
  def node_x(%{position: pos}), do: 80 + pos * 120

  def nodes_bottom_to_top(%{nodes: nodes}) do
    nodes |> Map.values() |> Enum.sort_by(& &1.floor)
  end

  def node_fill(:boss, true, _), do: "#7c3aed"
  def node_fill(:boss, _, _), do: "#4c1d95"
  def node_fill(:fight, true, _), do: "#b91c1c"
  def node_fill(:fight, _, _), do: "#7f1d1d"
  def node_fill(:elite, true, _), do: "#c2410c"
  def node_fill(:elite, _, _), do: "#7c2d12"
  def node_fill(:shop, true, _), do: "#b45309"
  def node_fill(:shop, _, _), do: "#78350f"
  def node_fill(:rest, true, _), do: "#15803d"
  def node_fill(:rest, _, _), do: "#14532d"

  def node_stroke(:boss, true), do: "#a78bfa"
  def node_stroke(:boss, _), do: "#7c3aed"
  def node_stroke(:fight, true), do: "#ef4444"
  def node_stroke(:fight, _), do: "#b91c1c"
  def node_stroke(:elite, true), do: "#fb923c"
  def node_stroke(:elite, _), do: "#c2410c"
  def node_stroke(:shop, true), do: "#fcd34d"
  def node_stroke(:shop, _), do: "#d97706"
  def node_stroke(:rest, true), do: "#4ade80"
  def node_stroke(:rest, _), do: "#16a34a"

  def node_icon(:boss), do: "💀"
  def node_icon(:fight), do: "⚔"
  def node_icon(:elite), do: "☠"
  def node_icon(:shop), do: "🏪"
  def node_icon(:rest), do: "🏕"
end
