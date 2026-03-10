defmodule DndWeb.GameLiveTest do
  use DndWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "XP visibility" do
    test "player XP is shown on the game board after starting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button[phx-click=start_game]") |> render_click()

      assert has_element?(view, "[data-testid=player-xp]")
    end

    test "monster XP reward is shown on the game board", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button[phx-click=start_game]") |> render_click()

      assert has_element?(view, "[data-testid=monster-xp]")
    end
  end

  describe "level visibility" do
    test "player level is shown on the game board after starting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("button[phx-click=start_game]") |> render_click()

      assert has_element?(view, "[data-testid=player-level]")
    end
  end
end
