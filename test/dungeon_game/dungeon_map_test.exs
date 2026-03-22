defmodule DungeonGame.DungeonMapTest do
  use ExUnit.Case, async: true

  alias DungeonGame.DungeonMap

  defp always(n), do: fn _sides -> n end

  # ---------------------------------------------------------------------------
  # generate/1
  # ---------------------------------------------------------------------------

  describe "generate/1" do
    test "returns a DungeonMap struct" do
      map = DungeonMap.generate(always(1))
      assert %DungeonMap{} = map
    end

    test "has 16 nodes total (3 per floor × 5 floors + 1 boss)" do
      map = DungeonMap.generate(always(1))
      assert map_size(map.nodes) == 16
    end

    test "boss node exists with type :boss on floor 5" do
      map = DungeonMap.generate(always(1))
      boss = map.nodes["boss"]
      assert boss.type == :boss
      assert boss.floor == 5
    end

    test "floors 0–4 each have exactly 3 nodes" do
      map = DungeonMap.generate(always(1))

      for floor <- 0..4 do
        nodes_on_floor =
          map.nodes
          |> Map.values()
          |> Enum.filter(&(&1.floor == floor))

        assert length(nodes_on_floor) == 3, "expected 3 nodes on floor #{floor}"
      end
    end

    test "all non-boss nodes have type :fight, :rest, :elite, or :shop" do
      map = DungeonMap.generate(always(1))

      non_boss = map.nodes |> Map.values() |> Enum.reject(&(&1.type == :boss))
      assert Enum.all?(non_boss, &(&1.type in [:fight, :rest, :elite, :shop]))
    end

    test "all floor-4 nodes connect to boss" do
      map = DungeonMap.generate(always(1))

      floor_4_nodes = map.nodes |> Map.values() |> Enum.filter(&(&1.floor == 4))
      assert Enum.all?(floor_4_nodes, &("boss" in &1.connections))
    end

    test "every node on floors 0–3 connects to at least one node on the next floor" do
      map = DungeonMap.generate(always(1))

      for floor <- 0..3 do
        nodes = map.nodes |> Map.values() |> Enum.filter(&(&1.floor == floor))

        Enum.each(nodes, fn node ->
          assert length(node.connections) >= 1,
                 "node #{node.id} on floor #{floor} has no connections"

          Enum.each(node.connections, fn conn_id ->
            target = map.nodes[conn_id]

            assert target.floor == floor + 1,
                   "node #{node.id} connects to #{conn_id} which is not on floor #{floor + 1}"
          end)
        end)
      end
    end

    test "starts with no current node and no visited nodes" do
      map = DungeonMap.generate(always(1))
      assert map.current_node_id == nil
      assert map.visited_ids == []
    end

    test "with roller always returning max (10), all non-boss nodes are :fight" do
      map = DungeonMap.generate(always(10))
      non_boss = map.nodes |> Map.values() |> Enum.reject(&(&1.type == :boss))
      fight_count = Enum.count(non_boss, &(&1.type == :fight))
      # roll 10 > elite threshold (4), so all are :fight
      assert fight_count == 15
    end

    test "with roller always returning 3 or 4, all non-boss nodes are :elite" do
      map = DungeonMap.generate(always(3))
      non_boss = map.nodes |> Map.values() |> Enum.reject(&(&1.type == :boss))
      assert Enum.all?(non_boss, &(&1.type == :elite))
    end

    test "with roller always returning 5 or 6, all non-boss nodes are :shop" do
      map = DungeonMap.generate(always(5))
      non_boss = map.nodes |> Map.values() |> Enum.reject(&(&1.type == :boss))
      assert Enum.all?(non_boss, &(&1.type == :shop))
    end
  end

  # ---------------------------------------------------------------------------
  # available_nodes/1
  # ---------------------------------------------------------------------------

  describe "available_nodes/1" do
    test "returns all floor-0 nodes when no current node (start of game)" do
      map = DungeonMap.generate(always(1))
      available = DungeonMap.available_nodes(map)
      assert length(available) == 3
      assert Enum.all?(available, &(&1.floor == 0))
    end

    test "returns connections of current node after visiting" do
      map = DungeonMap.generate(always(1))
      # Pick first floor-0 node and visit it
      floor_0_node = map.nodes |> Map.values() |> Enum.find(&(&1.floor == 0))
      map = DungeonMap.visit(map, floor_0_node.id)

      available = DungeonMap.available_nodes(map)
      expected_ids = floor_0_node.connections |> MapSet.new()
      actual_ids = available |> Enum.map(& &1.id) |> MapSet.new()
      assert actual_ids == expected_ids
    end

    test "excludes already-visited nodes from available" do
      map = DungeonMap.generate(always(1))
      floor_0_node = map.nodes |> Map.values() |> Enum.find(&(&1.floor == 0))
      map = DungeonMap.visit(map, floor_0_node.id)

      # Visit one of the next nodes
      next_node = map.nodes[hd(floor_0_node.connections)]
      map = DungeonMap.visit(map, next_node.id)

      available_ids = DungeonMap.available_nodes(map) |> Enum.map(& &1.id)
      refute next_node.id in available_ids
    end

    test "returns boss node when on floor 4" do
      map = DungeonMap.generate(always(1))

      # Walk to a floor-4 node
      map = walk_to_floor(map, 4)
      available_ids = DungeonMap.available_nodes(map) |> Enum.map(& &1.id)
      assert "boss" in available_ids
    end
  end

  # ---------------------------------------------------------------------------
  # visit/2
  # ---------------------------------------------------------------------------

  describe "visit/2" do
    test "sets current_node_id" do
      map = DungeonMap.generate(always(1))
      floor_0_node = map.nodes |> Map.values() |> Enum.find(&(&1.floor == 0))
      map = DungeonMap.visit(map, floor_0_node.id)
      assert map.current_node_id == floor_0_node.id
    end

    test "adds node id to visited_ids" do
      map = DungeonMap.generate(always(1))
      floor_0_node = map.nodes |> Map.values() |> Enum.find(&(&1.floor == 0))
      map = DungeonMap.visit(map, floor_0_node.id)
      assert floor_0_node.id in map.visited_ids
    end

    test "accumulates visited_ids over multiple visits" do
      map = DungeonMap.generate(always(1))
      map = walk_to_floor(map, 2)
      assert length(map.visited_ids) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # current_node/1
  # ---------------------------------------------------------------------------

  describe "current_node/1" do
    test "returns nil when no node visited yet" do
      map = DungeonMap.generate(always(1))
      assert DungeonMap.current_node(map) == nil
    end

    test "returns the current MapNode after visiting" do
      map = DungeonMap.generate(always(1))
      floor_0_node = map.nodes |> Map.values() |> Enum.find(&(&1.floor == 0))
      map = DungeonMap.visit(map, floor_0_node.id)
      assert DungeonMap.current_node(map) == floor_0_node
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Walks deterministically from start to the given floor by always picking
  # the first available node.
  defp walk_to_floor(map, target_floor) do
    Enum.reduce(0..target_floor, map, fn _floor, acc ->
      node = acc |> DungeonMap.available_nodes() |> hd()
      DungeonMap.visit(acc, node.id)
    end)
  end
end
