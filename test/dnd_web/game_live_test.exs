defmodule DndWeb.GameLiveTest do
  use DndWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "XP visibility" do
    test "player XP is shown on the game board after starting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      assert has_element?(view, "[data-testid=player-xp]")
    end

    test "monster XP reward is shown on the game board", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      assert has_element?(view, "[data-testid=monster-xp]")
    end
  end

  describe "gold visibility" do
    test "player gold is NOT shown on the fighting phase HUD", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      refute has_element?(view, "[data-testid=player-gold]")
    end

    test "player gold is shown in the inventory screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})
      view |> element("button[phx-click=open_inventory]") |> render_click()

      assert has_element?(view, "[data-testid=player-gold]")
    end
  end

  describe "level visibility" do
    test "player level is shown on the game board after starting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      assert has_element?(view, "[data-testid=player-level]")
    end
  end

  describe "inventory" do
    test "inventory button is visible during the fighting phase", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      assert has_element?(view, "button[phx-click=open_inventory]")
    end
  end

  describe "highscore display" do
    setup do
      DungeonGame.Highscore.clear()
      :ok
    end

    test "idle screen shows a highscore list section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "[data-testid=highscore-list]")
    end

    test "idle screen shows each entry's name and rounds survived", %{conn: conn} do
      DungeonGame.Highscore.add("Thorin", 7)
      DungeonGame.Highscore.add("Bilbo", 3)

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "[data-testid=highscore-list]", "Thorin")
      assert has_element?(view, "[data-testid=highscore-list]", "7")
      assert has_element?(view, "[data-testid=highscore-list]", "Bilbo")
      assert has_element?(view, "[data-testid=highscore-list]", "3")
    end

    test "game over screen shows the highscore list", %{conn: conn} do
      DungeonGame.Highscore.add("Thorin", 5)

      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      # Simulate combat until game_over — dismiss level-ups along the way
      Enum.reduce_while(1..200, :ok, fn _, _ ->
        cond do
          has_element?(view, "h2", "Game Over") ->
            {:halt, :done}

          has_element?(view, "button[phx-click=choose_upgrade]") ->
            render_click(view, "choose_upgrade", %{"id" => "tough"})
            {:cont, :ok}

          true ->
            view |> element("button[phx-value-action=attack]") |> render_click()
            {:cont, :ok}
        end
      end)

      assert has_element?(view, "h2", "Game Over")
      assert has_element?(view, "[data-testid=highscore-list]")
    end
  end

  describe "username entry" do
    test "idle screen shows a text input for the player's username", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "input[name=username]")
    end

    test "submitting a username starts the game and shows the name on the player card", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("form[phx-submit=start_game]")
      |> render_submit(%{username: "Thorin"})

      assert has_element?(view, "[data-testid=player-name]", "Thorin")
    end
  end
end
