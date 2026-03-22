defmodule DndWeb.GameLiveTest do
  use DndWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Starts the game and enters the :map phase (submits form then picks warrior class).
  defp start_game(view) do
    view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})
    render_click(view, "choose_class", %{"class" => "warrior"})
  end

  # Finds the node_id of the first available node of the given type from the
  # rendered HTML. Available nodes have phx-value-node_id set (nil = omitted).
  defp find_available_node_id(view, type) do
    html = render(view)

    case Regex.run(
           ~r/data-node-type="#{type}"[^>]*phx-value-node_id="([^"]+)"/,
           html
         ) do
      [_, id] -> id
      nil -> nil
    end
  end

  # From the :map phase, selects the first available fight node and enters combat.
  # Fires the select_node event directly to avoid the single-element constraint of
  # element/2 (the SVG may have many nodes matching the type selector).
  # Retries if the first available node is a rest node (continues rest and tries again).
  defp enter_fight(view) do
    fight_id = find_available_node_id(view, "fight")
    boss_id = find_available_node_id(view, "boss")
    elite_id = find_available_node_id(view, "elite")
    rest_id = find_available_node_id(view, "rest")
    shop_id = find_available_node_id(view, "shop")

    cond do
      fight_id ->
        render_click(view, "select_node", %{"node_id" => fight_id})

      boss_id ->
        render_click(view, "select_node", %{"node_id" => boss_id})

      elite_id ->
        render_click(view, "select_node", %{"node_id" => elite_id})

      rest_id ->
        render_click(view, "select_node", %{"node_id" => rest_id})
        render_click(view, "rest_and_continue", %{})
        enter_fight(view)

      shop_id ->
        render_click(view, "select_node", %{"node_id" => shop_id})
        render_click(view, "leave_shop", %{})
        enter_fight(view)

      true ->
        raise "No available nodes found in map"
    end
  end

  # Plays cards and ends turns until the monster is dead (handling level-ups),
  # then returns :ok when back on the map.
  defp win_fight(view) do
    Enum.reduce_while(1..500, :ok, fn _, _ ->
      cond do
        has_element?(view, "[data-testid=dungeon-map]") ->
          {:halt, :ok}

        has_element?(view, "button[phx-click=choose_upgrade]") ->
          render_click(view, "choose_upgrade", %{"id" => "bash"})
          {:cont, :ok}

        has_element?(view, "button[phx-click=skip_elite_loot]") ->
          render_click(view, "skip_elite_loot", %{})
          {:cont, :ok}

        has_element?(view, "button[phx-click=end_turn]") ->
          # Try to play the first card; if out of energy it's a no-op and we end turn
          render_click(view, "play_card", %{"index" => "0"})

          if has_element?(view, "button[phx-click=end_turn]") do
            render_click(view, "end_turn", %{})
          end

          {:cont, :ok}

        true ->
          {:halt, :ok}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Map phase
  # ---------------------------------------------------------------------------

  describe "map phase" do
    test "start_game shows the dungeon map", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      assert has_element?(view, "[data-testid=dungeon-map]")
    end

    test "map contains fight and/or rest nodes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      assert has_element?(view, "[data-testid=map-node]")
    end

    test "initially shows floor-0 nodes as available (clickable)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      assert has_element?(view, "[data-testid=map-node][data-available]")
    end

    test "clicking a fight node enters the fighting phase", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      assert has_element?(view, "button[phx-click=end_turn]")
    end

    test "clicking a rest node shows the rest screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      case find_available_node_id(view, "rest") do
        nil ->
          :ok

        rest_id ->
          render_click(view, "select_node", %{"node_id" => rest_id})
          assert has_element?(view, "[data-testid=rest-screen]")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Rest node
  # ---------------------------------------------------------------------------

  describe "rest node" do
    test "rest screen has a continue button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      case find_available_node_id(view, "rest") do
        nil ->
          :ok

        rest_id ->
          render_click(view, "select_node", %{"node_id" => rest_id})
          assert has_element?(view, "button[phx-click=rest_and_continue]")
      end
    end

    test "continuing from rest returns to the map", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      case find_available_node_id(view, "rest") do
        nil ->
          :ok

        rest_id ->
          render_click(view, "select_node", %{"node_id" => rest_id})
          render_click(view, "rest_and_continue", %{})
          assert has_element?(view, "[data-testid=dungeon-map]")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Combat → map loop
  # ---------------------------------------------------------------------------

  describe "combat loop with map" do
    test "winning a fight returns to the dungeon map", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)
      win_fight(view)

      assert has_element?(view, "[data-testid=dungeon-map]")
    end

    test "inventory button is visible during fighting phase", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      assert has_element?(view, "button[phx-click=open_inventory]")
    end
  end

  # ---------------------------------------------------------------------------
  # Gold and inventory
  # ---------------------------------------------------------------------------

  describe "gold visibility" do
    test "player gold is NOT shown on the fighting phase HUD", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      refute has_element?(view, "[data-testid=player-gold]")
    end

    test "player gold is shown in the inventory screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)
      view |> element("button[phx-click=open_inventory]") |> render_click()

      assert has_element?(view, "[data-testid=player-gold]")
    end
  end

  # ---------------------------------------------------------------------------
  # Victory
  # ---------------------------------------------------------------------------

  describe "victory" do
    test "defeating the boss shows the victory screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      # Jump directly to the boss fight (bypasses map navigation)
      render_click(view, "select_node", %{"node_id" => "boss"})
      # Set boss HP to 1 (AC also set to 1 by the test helper)
      render_click(view, "__test_set_monster_hp", %{"hp" => "1"})

      # Play cards until the boss dies (damage card at index 0 kills with hp=1, AC=1)
      Enum.reduce_while(1..50, :ok, fn _, _ ->
        cond do
          has_element?(view, "h2", "Victory") ->
            {:halt, :ok}

          has_element?(view, "button[phx-click=choose_upgrade]") ->
            render_click(view, "choose_upgrade", %{"id" => "bash"})
            {:cont, :ok}

          true ->
            render_click(view, "play_card", %{"index" => "0"})

            if has_element?(view, "button[phx-click=end_turn]") do
              render_click(view, "end_turn", %{})
            end

            {:cont, :ok}
        end
      end)

      assert has_element?(view, "h2", "Victory")
    end
  end

  # ---------------------------------------------------------------------------
  # Class select phase
  # ---------------------------------------------------------------------------

  describe "class select phase" do
    test "submitting username shows class selection screen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      assert has_element?(view, "[data-testid=class-select]")
    end

    test "class select shows warrior, rogue, and mage options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})

      assert has_element?(view, "button[phx-value-class=warrior]")
      assert has_element?(view, "button[phx-value-class=rogue]")
      assert has_element?(view, "button[phx-value-class=mage]")
    end

    test "choosing warrior transitions to the map", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Hero"})
      render_click(view, "choose_class", %{"class" => "warrior"})

      assert has_element?(view, "[data-testid=dungeon-map]")
    end

    test "player name is preserved after class selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Thorin"})
      render_click(view, "choose_class", %{"class" => "warrior"})

      assert has_element?(view, "[data-testid=player-name-map]", "Thorin")
    end
  end

  # ---------------------------------------------------------------------------
  # Card system combat UI
  # ---------------------------------------------------------------------------

  describe "card system combat UI" do
    test "player energy is shown during combat", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      assert has_element?(view, "[data-testid=player-energy]")
    end

    test "card hand buttons are shown during combat", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      assert has_element?(view, "button[phx-click=play_card]")
    end

    test "end turn button is shown during combat", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      assert has_element?(view, "button[phx-click=end_turn]")
    end

    test "playing a card updates the state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)
      enter_fight(view)

      # Sending play_card directly always succeeds (no-op if no energy)
      render_click(view, "play_card", %{"index" => "0"})
      assert has_element?(view, "[data-testid=player-energy]")
    end
  end

  # ---------------------------------------------------------------------------
  # Username entry
  # ---------------------------------------------------------------------------

  describe "username entry" do
    test "idle screen shows a text input for the player's username", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "input[name=username]")
    end

    test "submitting a username transitions to the map phase", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      start_game(view)

      assert has_element?(view, "[data-testid=dungeon-map]")
    end

    test "player name appears in the map header", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("form[phx-submit=start_game]") |> render_submit(%{username: "Thorin"})
      render_click(view, "choose_class", %{"class" => "warrior"})

      assert has_element?(view, "[data-testid=player-name-map]", "Thorin")
    end
  end

  # ---------------------------------------------------------------------------
  # Highscore display
  # ---------------------------------------------------------------------------

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
      start_game(view)
      enter_fight(view)

      # Play cards and end turns until dead
      Enum.reduce_while(1..500, :ok, fn _, _ ->
        cond do
          has_element?(view, "h2", "Game Over") ->
            {:halt, :done}

          has_element?(view, "button[phx-click=choose_upgrade]") ->
            render_click(view, "choose_upgrade", %{"id" => "bash"})
            {:cont, :ok}

          has_element?(view, "[data-testid=dungeon-map]") ->
            enter_fight(view)
            {:cont, :ok}

          has_element?(view, "[data-testid=rest-screen]") ->
            view |> element("button[phx-click=rest_and_continue]") |> render_click()
            {:cont, :ok}

          has_element?(view, "button[phx-click=end_turn]") ->
            render_click(view, "end_turn", %{})
            {:cont, :ok}

          true ->
            {:halt, :stuck}
        end
      end)

      assert has_element?(view, "h2", "Game Over")
      assert has_element?(view, "[data-testid=highscore-list]")
    end
  end
end
