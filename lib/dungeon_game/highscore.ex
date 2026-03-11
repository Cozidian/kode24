defmodule DungeonGame.Highscore do
  use Agent

  @max_entries 10

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def add(name, rounds) do
    Agent.get_and_update(__MODULE__, fn entries ->
      updated =
        [%{name: name, rounds: rounds} | entries]
        |> Enum.sort_by(& &1.rounds, :desc)
        |> Enum.take(@max_entries)

      {updated, updated}
    end)
  end

  def list do
    Agent.get(__MODULE__, & &1)
  end

  def clear do
    Agent.update(__MODULE__, fn _ -> [] end)
  end
end
