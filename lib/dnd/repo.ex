defmodule Dnd.Repo do
  use Ecto.Repo,
    otp_app: :dnd,
    adapter: Ecto.Adapters.SQLite3
end
