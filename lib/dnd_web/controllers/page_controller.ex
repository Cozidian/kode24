defmodule DndWeb.PageController do
  use DndWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
