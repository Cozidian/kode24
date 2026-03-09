defmodule DndWeb.PageControllerTest do
  use DndWeb.ConnCase

  test "GET / renders the game start screen", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Dungeon Crawler"
    assert html_response(conn, 200) =~ "Start Game"
  end
end
