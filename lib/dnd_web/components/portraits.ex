defmodule DndWeb.Portraits do
  @moduledoc "SVG character portrait components for the game UI."

  use Phoenix.Component

  attr :class, :string, default: "w-full h-full"

  def player(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 130" class={@class}>
      <%!-- Sword blade (behind body) --%>
      <rect x="74" y="10" width="6" height="50" rx="3" fill="#D1D5DB" />
      <rect x="68" y="36" width="18" height="5" rx="2" fill="#F59E0B" />
      <rect x="77" y="40" width="4" height="14" rx="2" fill="#92400E" />

      <%!-- Helmet --%>
      <ellipse cx="50" cy="20" rx="22" ry="14" fill="#4B5563" />
      <rect x="28" y="20" width="44" height="8" fill="#6B7280" />
      <%!-- Helmet plume --%>
      <rect x="46" y="6" width="8" height="12" rx="2" fill="#DC2626" />

      <%!-- Face --%>
      <rect x="31" y="24" width="38" height="22" rx="6" fill="#FBBF24" />
      <rect x="37" y="30" width="8" height="7" rx="2" fill="#1E3A5F" />
      <rect x="55" y="30" width="8" height="7" rx="2" fill="#1E3A5F" />
      <%!-- Eye highlights --%>
      <rect x="38" y="31" width="3" height="3" rx="1" fill="#60A5FA" />
      <rect x="56" y="31" width="3" height="3" rx="1" fill="#60A5FA" />

      <%!-- Body / armour --%>
      <rect x="22" y="46" width="56" height="42" rx="5" fill="#1D4ED8" />
      <%!-- Chest plate --%>
      <rect x="33" y="51" width="34" height="28" rx="3" fill="#3B82F6" />
      <%!-- Knight cross --%>
      <rect x="46" y="54" width="8" height="20" rx="1" fill="#F59E0B" />
      <rect x="40" y="60" width="20" height="7" rx="1" fill="#F59E0B" />
      <%!-- Belt --%>
      <rect x="22" y="82" width="56" height="6" fill="#92400E" />

      <%!-- Left arm + shield --%>
      <rect x="7" y="46" width="16" height="30" rx="4" fill="#1D4ED8" />
      <rect x="1" y="56" width="15" height="22" rx="4" fill="#D97706" />
      <rect x="3" y="58" width="11" height="18" rx="3" fill="#F59E0B" />
      <circle cx="8" cy="67" r="4" fill="#92400E" />

      <%!-- Right arm --%>
      <rect x="77" y="46" width="16" height="30" rx="4" fill="#1D4ED8" />

      <%!-- Legs --%>
      <rect x="25" y="88" width="22" height="28" rx="4" fill="#1E3A5F" />
      <rect x="53" y="88" width="22" height="28" rx="4" fill="#1E3A5F" />

      <%!-- Boots --%>
      <rect x="23" y="108" width="25" height="14" rx="4" fill="#111827" />
      <rect x="52" y="108" width="25" height="14" rx="4" fill="#111827" />
    </svg>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "w-full h-full"

  def monster(assigns) do
    ~H"""
    <%= case @name do %>
      <% "Goblin" -> %>
        <.goblin class={@class} />
      <% "Orc" -> %>
        <.orc class={@class} />
      <% "Troll" -> %>
        <.troll class={@class} />
      <% _ -> %>
        <.dragon class={@class} />
    <% end %>
    """
  end

  attr :class, :string, default: "w-full h-full"

  defp goblin(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 130" class={@class}>
      <%!-- Pointy ears --%>
      <polygon points="15,46 5,18 28,44" fill="#22C55E" />
      <polygon points="85,46 95,18 72,44" fill="#22C55E" />

      <%!-- Big round head --%>
      <ellipse cx="50" cy="46" rx="32" ry="30" fill="#22C55E" />

      <%!-- Yellow eyes (big and round) --%>
      <ellipse cx="37" cy="36" rx="11" ry="12" fill="#FDE047" />
      <ellipse cx="63" cy="36" rx="11" ry="12" fill="#FDE047" />
      <ellipse cx="39" cy="38" rx="7" ry="8" fill="#1F2937" />
      <ellipse cx="65" cy="38" rx="7" ry="8" fill="#1F2937" />
      <%!-- Pupil shine --%>
      <circle cx="37" cy="35" r="2" fill="white" />
      <circle cx="63" cy="35" r="2" fill="white" />

      <%!-- Nose --%>
      <ellipse cx="50" cy="52" rx="7" ry="5" fill="#16A34A" />

      <%!-- Mouth + teeth --%>
      <rect x="34" y="60" width="32" height="8" rx="3" fill="#1F2937" />
      <rect x="38" y="60" width="6" height="7" rx="1" fill="#F9FAFB" />
      <rect x="49" y="60" width="6" height="7" rx="1" fill="#F9FAFB" />

      <%!-- Small body --%>
      <rect x="32" y="76" width="36" height="28" rx="5" fill="#22C55E" />
      <rect x="36" y="84" width="28" height="10" fill="#78350F" />

      <%!-- Arms --%>
      <rect x="14" y="76" width="20" height="20" rx="4" fill="#22C55E" />
      <rect x="66" y="76" width="20" height="20" rx="4" fill="#22C55E" />

      <%!-- Club --%>
      <rect x="80" y="44" width="8" height="36" rx="3" fill="#92400E" />
      <ellipse cx="84" cy="42" rx="10" ry="9" fill="#78350F" />

      <%!-- Legs --%>
      <rect x="34" y="102" width="14" height="24" rx="3" fill="#16A34A" />
      <rect x="52" y="102" width="14" height="24" rx="3" fill="#16A34A" />
    </svg>
    """
  end

  attr :class, :string, default: "w-full h-full"

  defp orc(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 130" class={@class}>
      <%!-- Head (blocky) --%>
      <rect x="20" y="6" width="60" height="44" rx="6" fill="#6B7280" />
      <%!-- Brow ridge --%>
      <rect x="18" y="6" width="64" height="14" rx="4" fill="#4B5563" />
      <%!-- Small mean eyes --%>
      <rect x="28" y="14" width="14" height="10" rx="2" fill="#DC2626" />
      <rect x="58" y="14" width="14" height="10" rx="2" fill="#DC2626" />
      <rect x="31" y="16" width="7" height="6" rx="1" fill="#7F1D1D" />
      <rect x="61" y="16" width="7" height="6" rx="1" fill="#7F1D1D" />
      <%!-- Nose --%>
      <rect x="42" y="26" width="16" height="10" rx="3" fill="#4B5563" />
      <%!-- Jaw / lower face --%>
      <rect x="26" y="36" width="48" height="14" rx="4" fill="#374151" />
      <%!-- Tusks --%>
      <polygon points="36,48 32,66 42,62" fill="#F9FAFB" />
      <polygon points="64,48 68,66 58,62" fill="#F9FAFB" />

      <%!-- Broad body --%>
      <rect x="12" y="50" width="76" height="44" rx="5" fill="#6B7280" />
      <%!-- Chest straps --%>
      <rect x="24" y="56" width="52" height="28" rx="3" fill="#9CA3AF" />
      <rect x="47" y="56" width="6" height="28" fill="#6B7280" />
      <rect x="24" y="68" width="52" height="5" fill="#6B7280" />

      <%!-- Arms (thick) --%>
      <rect x="0" y="50" width="14" height="34" rx="4" fill="#6B7280" />
      <rect x="86" y="50" width="14" height="34" rx="4" fill="#6B7280" />

      <%!-- Axe --%>
      <rect x="87" y="16" width="8" height="42" rx="3" fill="#78350F" />
      <rect x="80" y="10" width="22" height="30" rx="4" fill="#9CA3AF" />
      <rect x="80" y="10" width="10" height="30" rx="2" fill="#6B7280" />

      <%!-- Legs --%>
      <rect x="18" y="94" width="28" height="28" rx="5" fill="#4B5563" />
      <rect x="54" y="94" width="28" height="28" rx="5" fill="#4B5563" />

      <%!-- Boots --%>
      <rect x="16" y="114" width="30" height="12" rx="4" fill="#1F2937" />
      <rect x="54" y="114" width="30" height="12" rx="4" fill="#1F2937" />
    </svg>
    """
  end

  attr :class, :string, default: "w-full h-full"

  defp troll(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 130" class={@class}>
      <%!-- Massive head --%>
      <ellipse cx="50" cy="30" rx="40" ry="30" fill="#78716C" />
      <%!-- Rocky bumps on head --%>
      <ellipse cx="24" cy="18" rx="8" ry="7" fill="#57534E" />
      <ellipse cx="76" cy="18" rx="8" ry="7" fill="#57534E" />
      <ellipse cx="50" cy="8" rx="10" ry="8" fill="#57534E" />
      <ellipse cx="38" cy="12" rx="5" ry="5" fill="#44403C" />
      <ellipse cx="62" cy="12" rx="5" ry="5" fill="#44403C" />

      <%!-- Tiny mean eyes --%>
      <ellipse cx="35" cy="24" rx="6" ry="6" fill="#DC2626" />
      <ellipse cx="65" cy="24" rx="6" ry="6" fill="#DC2626" />
      <ellipse cx="35" cy="25" rx="3" ry="4" fill="#7F1D1D" />
      <ellipse cx="65" cy="25" rx="3" ry="4" fill="#7F1D1D" />

      <%!-- Wide flat nose --%>
      <rect x="40" y="34" width="20" height="10" rx="5" fill="#57534E" />

      <%!-- Mouth (wide grimace) --%>
      <rect x="26" y="46" width="48" height="10" rx="3" fill="#292524" />
      <rect x="30" y="46" width="7" height="8" rx="1" fill="#D6D3D1" />
      <rect x="42" y="46" width="7" height="8" rx="1" fill="#D6D3D1" />
      <rect x="54" y="46" width="7" height="8" rx="1" fill="#D6D3D1" />

      <%!-- Massive body --%>
      <rect x="8" y="56" width="84" height="40" rx="6" fill="#78716C" />
      <ellipse cx="50" cy="76" rx="30" ry="20" fill="#57534E" />

      <%!-- Huge arms --%>
      <rect x="0" y="52" width="12" height="44" rx="5" fill="#78716C" />
      <rect x="88" y="52" width="12" height="44" rx="5" fill="#78716C" />

      <%!-- Boulder club --%>
      <rect x="86" y="20" width="10" height="38" rx="4" fill="#44403C" />
      <ellipse cx="91" cy="18" rx="14" ry="12" fill="#292524" />
      <ellipse cx="87" cy="14" rx="5" ry="5" fill="#44403C" />

      <%!-- Legs --%>
      <rect x="10" y="94" width="34" height="28" rx="6" fill="#57534E" />
      <rect x="56" y="94" width="34" height="28" rx="6" fill="#57534E" />
    </svg>
    """
  end

  attr :class, :string, default: "w-full h-full"

  defp dragon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 130" class={@class}>
      <%!-- Wings (behind everything) --%>
      <polygon points="50,60 4,16 14,80" fill="#991B1B" />
      <polygon points="50,60 96,16 86,80" fill="#991B1B" />
      <%!-- Wing membranes (lighter inner) --%>
      <polygon points="50,60 14,22 14,72" fill="#B91C1C" />
      <polygon points="50,60 86,22 86,72" fill="#B91C1C" />

      <%!-- Neck --%>
      <rect x="40" y="26" width="20" height="28" rx="5" fill="#DC2626" />

      <%!-- Head --%>
      <rect x="28" y="6" width="44" height="28" rx="7" fill="#DC2626" />
      <%!-- Horns --%>
      <polygon points="32,8 24,0 38,14" fill="#7F1D1D" />
      <polygon points="68,8 76,0 62,14" fill="#7F1D1D" />
      <%!-- Eyes (gold, slit pupils) --%>
      <ellipse cx="38" cy="14" rx="7" ry="7" fill="#FCD34D" />
      <ellipse cx="62" cy="14" rx="7" ry="7" fill="#FCD34D" />
      <ellipse cx="38" cy="14" rx="2" ry="5" fill="#1C1917" />
      <ellipse cx="62" cy="14" rx="2" ry="5" fill="#1C1917" />
      <%!-- Nostrils --%>
      <ellipse cx="40" cy="26" rx="3" ry="3" fill="#7F1D1D" />
      <ellipse cx="60" cy="26" rx="3" ry="3" fill="#7F1D1D" />
      <%!-- Fire breath --%>
      <polygon points="72,20 100,6 96,22 100,12 92,28 84,18 80,32" fill="#F97316" />
      <polygon points="74,22 96,10 92,24 86,22 82,30" fill="#FCD34D" />

      <%!-- Body --%>
      <rect x="24" y="54" width="52" height="40" rx="8" fill="#DC2626" />
      <%!-- Belly scales --%>
      <ellipse cx="50" cy="74" rx="18" ry="16" fill="#FCA5A5" />
      <ellipse cx="50" cy="74" rx="12" ry="10" fill="#FECACA" />

      <%!-- Legs --%>
      <rect x="20" y="88" width="24" height="30" rx="5" fill="#B91C1C" />
      <rect x="56" y="88" width="24" height="30" rx="5" fill="#B91C1C" />
      <%!-- Claws --%>
      <polygon points="20,116 14,130 24,122" fill="#7F1D1D" />
      <polygon points="28,118 24,130 34,124" fill="#7F1D1D" />
      <polygon points="56,116 50,130 60,122" fill="#7F1D1D" />
      <polygon points="72,118 68,130 78,124" fill="#7F1D1D" />
    </svg>
    """
  end
end
