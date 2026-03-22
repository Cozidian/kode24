defmodule DungeonGame.DungeonMap do
  @moduledoc """
  Represents the dungeon map and handles generation and navigation.

  The map has 5 regular floors (0–4) with 3 nodes each, plus a boss node on
  floor 5. Each non-boss node connects forward to 1–2 nodes on the next floor.
  All floor-4 nodes connect to the boss.

  Node types on floors 0–4 are randomly `:fight` (~80%) or `:rest` (~20%).
  The boss node is always `:boss`.
  """

  alias DungeonGame.MapNode

  defstruct [:nodes, :current_node_id, :visited_ids]

  @floors 0..4
  @nodes_per_floor 3
  # Thresholds out of 10: roll ≤ 2 → :rest, 3–4 → :elite, 5–6 → :shop, 7–10 → :fight
  @rest_threshold 2
  @elite_threshold 4
  @shop_threshold 6

  @doc """
  Generates a fresh dungeon map using the injectable `roller` function.
  `roller` is called as `roller.(n)` and must return an integer in 1..n.
  """
  def generate(roller \\ &:rand.uniform/1) do
    nodes =
      @floors
      |> Enum.flat_map(&build_floor_nodes(&1, roller))
      |> then(fn floor_nodes -> floor_nodes ++ [boss_node()] end)
      |> connect_nodes(roller)
      |> Map.new(&{&1.id, &1})

    %__MODULE__{nodes: nodes, current_node_id: nil, visited_ids: []}
  end

  @doc """
  Returns the list of `%MapNode{}` structs the player may move to next.

  - Before any move: all floor-0 nodes.
  - After a move: the connections of the current node, excluding already-visited nodes.
  """
  def available_nodes(%__MODULE__{current_node_id: nil, nodes: nodes}) do
    nodes |> Map.values() |> Enum.filter(&(&1.floor == 0))
  end

  def available_nodes(%__MODULE__{
        current_node_id: current_id,
        nodes: nodes,
        visited_ids: visited
      }) do
    current = nodes[current_id]

    current.connections
    |> Enum.reject(&(&1 in visited))
    |> Enum.map(&nodes[&1])
  end

  @doc """
  Marks `node_id` as visited and sets it as the current node.
  """
  def visit(%__MODULE__{} = map, node_id) do
    %{map | current_node_id: node_id, visited_ids: [node_id | map.visited_ids]}
  end

  @doc """
  Returns the current `%MapNode{}`, or `nil` if none visited yet.
  """
  def current_node(%__MODULE__{current_node_id: nil}), do: nil

  def current_node(%__MODULE__{current_node_id: id, nodes: nodes}), do: nodes[id]

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_floor_nodes(floor, roller) do
    Enum.map(0..(@nodes_per_floor - 1), fn pos ->
      %MapNode{
        id: "f#{floor}p#{pos}",
        type: node_type(roller),
        floor: floor,
        position: pos,
        connections: []
      }
    end)
  end

  defp boss_node do
    %MapNode{id: "boss", type: :boss, floor: 5, position: 0, connections: []}
  end

  # Roll 1..10; ≤ rest → :rest, ≤ elite → :elite, ≤ shop → :shop, else :fight
  defp node_type(roller) do
    roll = roller.(10)

    cond do
      roll <= @rest_threshold -> :rest
      roll <= @elite_threshold -> :elite
      roll <= @shop_threshold -> :shop
      true -> :fight
    end
  end

  # Wire up connections: each floor-N node connects to 1–2 floor-(N+1) nodes,
  # ensuring every node is reachable and all floor-4 nodes reach the boss.
  defp connect_nodes(nodes, roller) do
    nodes_by_floor = Enum.group_by(nodes, & &1.floor)

    @floors
    |> Enum.reduce(nodes, fn floor, acc ->
      current_floor_nodes = nodes_by_floor[floor]

      next_floor_nodes =
        if floor == 4,
          do: nodes_by_floor[5],
          else: nodes_by_floor[floor + 1]

      next_ids = Enum.map(next_floor_nodes, & &1.id)

      # Assign each current-floor node at least one random connection forward
      {updated_current, _} =
        Enum.map_reduce(current_floor_nodes, next_ids, fn node, remaining_ids ->
          # Always connect to one, optionally a second
          primary_idx = rem(node.position, length(remaining_ids))
          primary_id = Enum.at(remaining_ids, primary_idx)

          extra_ids =
            if roller.(2) == 1 do
              # 50% chance of a second connection to an adjacent next-floor node
              alt_idx = rem(node.position + 1, length(next_ids))
              alt_id = Enum.at(next_ids, alt_idx)
              if alt_id != primary_id, do: [alt_id], else: []
            else
              []
            end

          connections = Enum.uniq([primary_id | extra_ids])
          {%{node | connections: connections}, remaining_ids}
        end)

      # Merge updated nodes back into acc
      Enum.map(acc, fn n ->
        Enum.find(updated_current, n, &(&1.id == n.id))
      end)
    end)
  end
end
