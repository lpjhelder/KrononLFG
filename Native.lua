-- KrononLFG — Native: ancora no finder de Grupos Prontos NATIVO (modelo Premade
-- Groups Filter) e decora as linhas de Mítica+ com o PREVIEW DE DROPS ao passar a
-- seta. A busca por nível de chave é SERVER-SIDE pela caixa de nome nativa (única
-- forma que funciona); aqui só REALÇAMOS o que o servidor já devolveu.
--
-- ⚠️ À PROVA DE TAINT (regras confirmadas lendo o PGF):
--   • só hooksecurefunc (post-hook) + frame:HookScript (aditivo);
--   • overlays/estado guardados em TABELA PRÓPRIA chaveada pela entry — NUNCA
--     escrevemos campo na frame nativa (entry.x = ... taina o Inscrever-se);
--   • NUNCA tocamos no SignUpButton nem chamamos ApplyToGroup (apply fica 100%
--     nativo); só lemos (GetSearchResultInfo) e mexemos no GameTooltip (display).
-- Hookamos LFGListSearchEntry_Update (roda por linha a cada refresh), depois que
-- o Blizzard_GroupFinder (load-on-demand) carregar.

local KLFG = KrononLFG
if not KLFG then return end
local L = KLFG.L

local entryData = {}   -- [entryFrame] = { cm = challengeModeId }  (NUNCA na frame nativa)
local hooked = false

-- Acrescenta as linhas de recompensa + drops ao tooltip da entry (no nível de
-- chave selecionado no KrononLFG). Se o tooltip nativo já estiver montado nesta
-- entry, só ANEXA; senão, monta um header próprio. Nunca reseta conteúdo alheio.
local function ShowDrops(entry, cm)
  if not cm or not GameTooltip then return end
  if GameTooltip:GetOwner() ~= entry then
    GameTooltip:SetOwner(entry, "ANCHOR_RIGHT")
    GameTooltip:SetText("KrononLFG", 0.85, 0.68, 0.35)
  else
    GameTooltip:AddLine(" ")
  end

  local name = (KLFG.DungeonName and KLFG.DungeonName(cm)) or ""
  GameTooltip:AddLine(name, 0.85, 0.68, 0.35)

  local kl = (KLFG.GetKeyLevel and KLFG.GetKeyLevel()) or 2
  local function Tier(code) return (KLFG.TierName and KLFG.TierName(code)) or "?" end
  local r = KLFG.RewardForKey and KLFG.RewardForKey(kl)
  if r then
    GameTooltip:AddDoubleLine(
      string.format(L.PREVIEW_ENDOFRUN_FMT, r.endI, Tier(r.endT), r.endR),
      string.format("ilvl %d", r.endI), 0.85, 0.7, 0.35, 0.85, 0.7, 0.35)
    GameTooltip:AddDoubleLine(
      string.format(L.PREVIEW_VAULT_FMT, r.vaultI, Tier(r.vaultT), r.vaultR),
      string.format("ilvl %d", r.vaultI), 0.8, 0.8, 1, 0.45, 0.8, 0.85)
  end

  local data = KLFG.Loot and KLFG.Loot.GetDrops and KLFG.Loot.GetDrops(cm)
  if data and data.ready and data.items and #data.items > 0 then
    GameTooltip:AddLine(L.PREVIEW_DROPS or "Drops", 0.85, 0.7, 0.35)
    local n = 0
    for _, it in ipairs(data.items) do
      if it.name then
        GameTooltip:AddLine("  " .. it.name, 0.9, 0.9, 0.9)
        n = n + 1
        if n >= 12 then break end
      end
    end
  elseif KLFG.Loot and KLFG.Loot.IsLoading and KLFG.Loot.IsLoading(cm) then
    GameTooltip:AddLine(L.PREVIEW_LOADING or "...", 0.6, 0.6, 0.6)
  end

  GameTooltip:Show()
end

-- Post-hook de LFGListSearchEntry_Update: resolve a masmorra do grupo e instala
-- (uma vez por frame) o gatilho de tooltip. Frames são RECICLADAS pelo ScrollBox,
-- então atualizamos o cm a cada chamada.
local function DecorateEntry(entry)
  if not entry or not entry.resultID then return end
  if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return end
  local ok, info = pcall(C_LFGList.GetSearchResultInfo, entry.resultID)
  if not ok or type(info) ~= "table" then return end

  local cm = KLFG.ResultCM and KLFG.ResultCM(info) or nil
  local d = entryData[entry]
  if not d then
    d = {}
    entryData[entry] = d
    entry:HookScript("OnEnter", function(self)
      local dd = entryData[self]
      if dd and dd.cm then pcall(ShowDrops, self, dd.cm) end
    end)
    -- OnLeave: o tooltip se esconde sozinho no fluxo nativo; nada a fazer.
  end
  d.cm = cm
end

local function TryHook()
  if hooked then return end
  if type(_G.LFGListSearchEntry_Update) == "function" then
    hooksecurefunc("LFGListSearchEntry_Update", DecorateEntry)
    hooked = true
  end
end

-- O Blizzard_GroupFinder é load-on-demand: hookamos quando ele carregar (ou já no
-- login, se ativado por outro addon como o próprio PGF).
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, ev, name)
  if (ev == "ADDON_LOADED" and name == "Blizzard_GroupFinder") or ev == "PLAYER_LOGIN" then
    TryHook()
  end
end)
TryHook() -- caso o group finder já esteja carregado
