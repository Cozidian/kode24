defmodule DungeonGame.MapNode do
  @moduledoc """
  A single node on the dungeon map.

  - `id` — unique string, e.g. "f0p1" or "boss"
  - `type` — `:fight | :rest | :boss`
  - `floor` — 0–5 (floor 5 is the boss)
  - `position` — 0–2 (column within the floor; unused for boss)
  - `connections` — list of node ids on the next floor this node leads to
  """

  defstruct [:id, :type, :floor, :position, :connections]
end
