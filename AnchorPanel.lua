-- KrononLFG — AnchorPanel: painel de controle ANCORADO ao finder de Grupos
-- Prontos nativo (modelo Premade Groups Filter), com a aparência do KrononLFG.
-- Mostra: nível de chave, liga, seleção de masmorras e recompensas — com a nossa
-- cara (navy/dourado). A busca por chave continua na caixa nativa (server-side) e
-- o Inscrever-se fica 100% nativo.
--
-- ⚠️ À PROVA DE TAINT (regras do PGF): o painel é filho do PVEFrame (container,
-- não-protegido), ancorado via SetPoint(PVEFrame). Só hooksecurefunc/HookScript.
-- O filtro de dungeon é CLIENT-SIDE (esconde da lista exibida + re-renderiza),
-- igual ao PGF — sem re-buscar, sem tocar em ação protegida. A chave fica na
-- caixa nativa (server-side) e o Inscrever-se fica 100% nativo.

local KLFG = KrononLFG
if not KLFG then return end
local L = KLFG.L

-- Paleta (mesma linguagem visual da janela standalone)
local NAVY   = { 0.04, 0.06, 0.09 }
local PANEL  = { 0.06, 0.09, 0.14 }
local ACCENT = { 0.85, 0.68, 0.35 }
local TEAL   = { 0.25, 0.71, 0.79 }
local TEXT   = { 0.86, 0.86, 0.90 }
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local LOGO   = "Interface\\AddOns\\KrononLFG\\Media\\KrononLogo"

local panel       -- frame raiz (lazy)
local built = false
local dchecks = {}

-- ---------------------------------------------------------------------------
-- helpers de estilo (locais, pra não depender dos locais da UI.lua)
-- ---------------------------------------------------------------------------
local function FS(parent, font, text, color)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
  fs:SetText(text or "")
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  return fs
end

local function MakeCheck(parent, label)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(20, 20)
  c.label = FS(c, "GameFontHighlightSmall", label, TEXT)
  c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
  return c
end

-- cmID -> activityGroupID do LFGList (dado da season; mesmos valores do DB2 que o
-- PGF usa). EDITAR a cada season junto com KLFG.DUNGEON_DATA. Usado pra casar a
-- activity de cada grupo com a masmorra marcada (filtro client-side).
local CM_TO_AGID = {
  -- Midnight Season 1
  [560] = 400, -- Cavernas de Maisara
  [559] = 401, -- Ponto de Nexus Xenas
  [558] = 399, -- Terraço dos Magísteres
  [557] = 370, -- Beira-céu (Windrunner Spire)
  [402] = 302, -- Academia Algeth'ar
  [239] = 133, -- Sede do Triunvirato
  [161] = 9,   -- Pico dos Correventos (Skyreach)
  [556] = 52,  -- Fosso de Saron
}

-- Lista CHEIA (sem nosso filtro) da última atualização nativa. Filtramos a partir
-- dela (modelo PGF: cacheia o full e re-filtra cópias), nunca da lista já filtrada.
local lastFull = {}

-- Filtro CLIENT-SIDE por dungeon (modelo PGF): mantém só os grupos das masmorras
-- marcadas e re-renderiza — INSTANTÂNEO, sem re-buscar (evita throttle/vermelho do
-- DoSearch repetido). ⚠️ Taint-safe: lê resultados, atribui CÓPIA em
-- .results/.totalResults (igual ao PGF) e chama UpdateResults. Nenhuma ação protegida.
local function FilterCurrentResults()
  local sp = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
  if not sp or type(lastFull) ~= "table" then return end
  if not (C_LFGList and C_LFGList.GetActivityInfoTable and C_LFGList.GetSearchResultInfo) then return end

  local selAGID, nSel = {}, 0
  local sel = (KLFG.GetSelectedDungeons and KLFG.GetSelectedDungeons()) or {}
  for _, cm in ipairs(sel) do
    local a = CM_TO_AGID[cm]
    if a then selAGID[a] = true; nSel = nSel + 1 end
  end

  local out
  if nSel == 0 or nSel >= 8 then
    out = lastFull -- nada/todas marcadas → lista cheia (sem filtro)
  else
    out = {}
    for _, rid in ipairs(lastFull) do
      local keep = true
      local ok, info = pcall(C_LFGList.GetSearchResultInfo, rid)
      if ok and type(info) == "table" then
        local actID = info.activityID
        if not actID and type(info.activityIDs) == "table" then actID = info.activityIDs[1] end
        if actID then
          local okA, at = pcall(C_LFGList.GetActivityInfoTable, actID)
          local agid = okA and type(at) == "table" and at.groupFinderActivityGroupID
          if agid then keep = (selAGID[agid] == true) end
        end
      end
      if keep then out[#out + 1] = rid end
    end
  end
  sp.results = out
  sp.totalResults = #out
  if _G.LFGListSearchPanel_UpdateResults then pcall(_G.LFGListSearchPanel_UpdateResults, sp) end
end

-- Posição: padrão = à direita do PVEFrame; se o usuário arrastou, usa a salva
-- (relativa à tela), pra sair de cima do RaiderIO/PGF/etc.
local function ApplyPosition(f)
  f:ClearAllPoints()
  local db = KLFG.GetDB and KLFG.GetDB()
  if db and db.anchorX and db.anchorY then
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.anchorX, db.anchorY)
  else
    f:SetPoint("TOPLEFT", _G.PVEFrame, "TOPRIGHT", -2, -10)
  end
end

-- ---------------------------------------------------------------------------
-- Drops por dungeon (Encounter Journal via KLFG.Loot) + destaque dos favoritos do
-- KeystoneLoot (BiS / Essencial / Bom ter / Transmog), igual o KrononAlts. Tudo
-- defensivo: sem KeystoneLoot/sem dados → só mostra os ícones, sem bordas.
-- ---------------------------------------------------------------------------
local function CurrentSpecId()
  local C = C_SpecializationInfo
  if type(C) == "table" and type(C.GetSpecialization) == "function" and type(C.GetSpecializationInfo) == "function" then
    local ok, idx = pcall(C.GetSpecialization)
    if ok and type(idx) == "number" then
      local ok2, s = pcall(C.GetSpecializationInfo, idx)
      if ok2 and type(s) == "number" and s > 0 then return s end
    end
  end
  if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
    local ok, idx = pcall(GetSpecialization)
    if ok and type(idx) == "number" then
      local ok2, s = pcall(GetSpecializationInfo, idx)
      if ok2 and type(s) == "number" and s > 0 then return s end
    end
  end
  return nil
end

-- characterKey EXATO do KeystoneLoot: "realm-nome-classId".
local function KLCharacterKey()
  if type(GetRealmName) ~= "function" or type(UnitName) ~= "function" or type(UnitClass) ~= "function" then return nil end
  local ok1, realm = pcall(GetRealmName)
  local ok2, name = pcall(UnitName, "player")
  local ok3, _, _, classId = pcall(UnitClass, "player")
  if ok1 and ok2 and ok3 and type(realm) == "string" and realm ~= "" and type(name) == "string" and name ~= "" and type(classId) == "number" then
    return string.format("%s-%s-%d", realm, name, classId)
  end
  return nil
end

-- tier do item nos favoritos do KeystoneLoot (cm + spec atual). 3=BiS, 2=Essencial,
-- 1=Bom ter, 4=Transmog. nil = não marcado. SavedVariable GLOBAL KeystoneLootDB.
local function ItemTier(cm, itemId)
  if not itemId then return nil end
  local db = rawget(_G, "KeystoneLootDB")
  if type(db) ~= "table" or type(db.favorites) ~= "table" then return nil end
  local key, spec = KLCharacterKey(), CurrentSpecId()
  if not (key and spec) then return nil end
  local favs = db.favorites[key]; if type(favs) ~= "table" then return nil end
  local sm = favs[cm]; if type(sm) ~= "table" then return nil end
  local spm = sm[spec]; if type(spm) ~= "table" then return nil end
  local info = spm[itemId]
  if type(info) == "table" and type(info.tier) == "number" then return info.tier end
  return nil
end

local TIER_COLOR = {
  [3] = { 1.00, 0.84, 0.00 }, -- BiS (dourado)
  [2] = { 1.00, 0.45, 0.10 }, -- Essencial (laranja)
  [1] = { 0.25, 0.85, 0.35 }, -- Bom ter (verde)
  [4] = { 0.70, 0.45, 1.00 }, -- Transmog (roxo)
}
local TIER_NAME = { [3] = "BiS", [2] = "Essencial", [1] = "Bom ter", [4] = "Transmog" }

local DROP_X, DROP_N, DROP_SZ, DROP_GAP = 148, 18, 20, 2

-- popula/atualiza a tira de ícones de drop de uma linha de dungeon
local function PopulateDrops(row)
  if not row then return end
  row.icons = row.icons or {}
  local cm = row.cm
  local data = (KLFG.Loot and KLFG.Loot.GetDrops) and KLFG.Loot.GetDrops(cm) or nil
  local raw = (data and data.ready and data.items) or {}
  -- empacota contíguo: só itens COM ícone, sem duplicar itemID (o EJ repete muito)
  local items, seen = {}, {}
  for _, it in ipairs(raw) do
    if it.icon and (not it.itemID or not seen[it.itemID]) then
      if it.itemID then seen[it.itemID] = true end
      items[#items + 1] = it
    end
  end
  for j = 1, DROP_N do
    local it = items[j]
    local b = row.icons[j]
    if it and it.icon then
      if not b then
        b = CreateFrame("Button", nil, row)
        b:SetSize(DROP_SZ, DROP_SZ)
        b:SetPoint("LEFT", row, "LEFT", DROP_X + (j - 1) * (DROP_SZ + DROP_GAP), 0)
        b.border = b:CreateTexture(nil, "BACKGROUND")
        b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
        b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          local kl = (KLFG.GetKeyLevel and KLFG.GetKeyLevel()) or 2
          -- link ESCALADO pro ilvl do nível de chave (mostra o item no ilvl certo)
          local link = self.itemID and KLFG.Loot and KLFG.Loot.UpgradedLink and KLFG.Loot.UpgradedLink(self.itemID, kl)
          if link then
            pcall(GameTooltip.SetHyperlink, GameTooltip, link)
          elseif self.itemID then
            pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
          end
          GameTooltip:AddLine(string.format("+%d (fim da run)", kl), 0.85, 0.7, 0.35)
          if self.tier and TIER_NAME[self.tier] then
            local col = TIER_COLOR[self.tier]
            GameTooltip:AddLine("KeystoneLoot: " .. TIER_NAME[self.tier], col[1], col[2], col[3])
          end
          GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.icons[j] = b
      end
      b.tex:SetTexture(it.icon)
      b.itemID = it.itemID
      local tier = ItemTier(cm, it.itemID)
      b.tier = tier
      if tier and TIER_COLOR[tier] then
        local col = TIER_COLOR[tier]
        b.border:SetColorTexture(col[1], col[2], col[3], 1)
        b.border:Show()
      else
        b.border:Hide()
      end
      b:Show()
    elseif b then
      b:Hide()
    end
  end
end

-- ---------------------------------------------------------------------------
-- construção (lazy: só quando o finder nativo aparece a 1ª vez)
-- ---------------------------------------------------------------------------
local function BuildPanel()
  if built then return end
  if not _G.PVEFrame then return end
  built = true

  local f = CreateFrame("Frame", "KrononLFGAnchorPanel", _G.PVEFrame, "BackdropTemplate")
  panel = f
  f:SetSize(560, 506)
  f:SetFrameStrata("HIGH")
  -- arrastável + posição lembrada (pra tirar de cima do RaiderIO/outros addons)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local db = KLFG.GetDB and KLFG.GetDB()
    if db and self:GetLeft() then db.anchorX = self:GetLeft(); db.anchorY = self:GetTop() end
  end)
  ApplyPosition(f)
  if f.SetBackdrop then
    pcall(f.SetBackdrop, f, {
      bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 2,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    pcall(f.SetBackdropColor, f, NAVY[1], NAVY[2], NAVY[3], 1)
    pcall(f.SetBackdropBorderColor, f, ACCENT[1], ACCENT[2], ACCENT[3], 0.85)
  end

  -- cabeçalho: logo + título
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(28, 28)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
  if not pcall(logo.SetTexture, logo, LOGO) then logo:Hide() end
  f.title = FS(f, "GameFontNormalLarge", "KrononLFG", ACCENT)
  f.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)

  -- divisória
  local div = f:CreateTexture(nil, "ARTWORK")
  div:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -40)
  div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -40)
  div:SetHeight(1)
  div:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.5)

  -- liga + nível de chave (stepper)
  f.league = FS(f, "GameFontHighlight", "", TEAL)
  f.league:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -48)

  local keyLbl = FS(f, "GameFontHighlightSmall", L.SELECT_KEY_LEVEL or "Chave", TEXT)
  keyLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -70)
  local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  minus:SetSize(24, 22); minus:SetText("-")
  minus:SetPoint("TOPLEFT", keyLbl, "BOTTOMLEFT", 0, -2)
  f.keyVal = FS(f, "GameFontNormalLarge", "", ACCENT)
  f.keyVal:SetPoint("LEFT", minus, "RIGHT", 10, 0)
  local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  plus:SetSize(24, 22); plus:SetText("+")
  plus:SetPoint("LEFT", minus, "RIGHT", 44, 0)
  minus:SetScript("OnClick", function() if KLFG.SetKeyLevel then KLFG.SetKeyLevel((KLFG.GetKeyLevel and KLFG.GetKeyLevel() or 2) - 1) end end)
  plus:SetScript("OnClick", function() if KLFG.SetKeyLevel then KLFG.SetKeyLevel((KLFG.GetKeyLevel and KLFG.GetKeyLevel() or 2) + 1) end end)

  -- recompensas (fim da run / cofre / brasão) no nível selecionado
  f.reward = FS(f, "GameFontHighlightSmall", "", TEXT)
  f.reward:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -116)
  f.reward:SetWidth(196); f.reward:SetJustifyH("LEFT")
  f.reward:SetSpacing(3)

  -- masmorras: linhas EXPANDIDAS com a ARTE da dungeon ao fundo (fade pra direita)
  local dl = FS(f, "GameFontNormal", L.SELECT_DUNGEONS or "Dungeons", ACCENT)
  dl:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -176)
  dchecks = {}
  local data = KLFG.DUNGEON_DATA or {}
  local ROW_H, ROW_W, ART_W = 32, 546, 200
  for i, d in ipairs(data) do
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(ROW_W, ROW_H)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 9, -196 - (i - 1) * (ROW_H + 2))
    row.cm = d.cm

    -- arte da dungeon (só à ESQUERDA, largura ART_W) + FADE pra direita
    local bg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bg:SetWidth(ART_W)
    local tex = KLFG.DungeonBG and KLFG.DungeonBG(d.cm)
    if tex then
      bg:SetTexture(tex)
      bg:SetTexCoord(0, 1, 0.30, 0.70) -- corta faixa horizontal (menos distorção)
    else
      bg:SetColorTexture(PANEL[1], PANEL[2], PANEL[3], 0.6)
    end
    if not pcall(bg.SetGradient, bg, "HORIZONTAL", CreateColor(1, 1, 1, 0.7), CreateColor(1, 1, 1, 0)) then
      pcall(bg.SetGradientAlpha, bg, "HORIZONTAL", 1, 1, 1, 0.7, 1, 1, 1, 0)
    end
    -- leve escurecida sob o nome (só na faixa da arte)
    local shade = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    shade:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    shade:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    shade:SetWidth(ART_W)
    shade:SetColorTexture(0, 0, 0, 0.28)

    -- checkbox
    local c = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    c:SetPoint("LEFT", row, "LEFT", 2, 0)
    c.cm = d.cm
    c:SetScript("OnClick", function(self)
      -- painel ancorado = seleção MANUAL (no modo "auto" devolve todas)
      if KLFG.SetDungeonMode then KLFG.SetDungeonMode("manual") end
      if KLFG.ToggleDungeon then KLFG.ToggleDungeon(self.cm) end
      if KLFG.bus then KLFG.bus:Fire("config") end
      FilterCurrentResults() -- re-filtra a lista atual instantâneo (sem re-buscar)
    end)

    -- nome da dungeon (sobre a arte, faixa estreita à esquerda)
    local nm = FS(row, "GameFontHighlight", "", { 1, 1, 1 })
    nm:SetPoint("LEFT", c, "RIGHT", 4, 0)
    nm:SetWidth(116)
    nm:SetJustifyH("LEFT")
    nm:SetWordWrap(false)
    c.label = nm -- UpdateContent usa c.label:SetText(DungeonName)

    c.row = row
    dchecks[i] = c
    PopulateDrops(row) -- dispara o load dos drops (async; "loot" re-popula)
  end

  -- rodapé: lembrete da chave na caixa nativa
  f.hint = FS(f, "GameFontDisableSmall", L.ANCHOR_KEY_HINT or "", { 0.6, 0.62, 0.68 })
  f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
  f.hint:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
  f.hint:SetJustifyH("LEFT")

  f:Hide()
end

-- ---------------------------------------------------------------------------
-- conteúdo dinâmico
-- ---------------------------------------------------------------------------
local function Tier(code) return (KLFG.TierName and KLFG.TierName(code)) or "?" end

local function UpdateContent()
  if not panel then return end
  local kl = (KLFG.GetKeyLevel and KLFG.GetKeyLevel()) or 2
  panel.keyVal:SetText("+" .. kl)

  -- liga atual
  local lgName = ""
  if KLFG.GetLeague and KLFG.GetLeagueById then
    local lg = KLFG.GetLeagueById(KLFG.GetLeague())
    if lg and lg.titleKey then lgName = L[lg.titleKey] or "" end
  end
  panel.league:SetText(lgName ~= "" and (("%s: %s"):format(L.TAB_LEAGUES or "Liga", lgName)) or "")

  -- recompensas no nível
  local r = KLFG.RewardForKey and KLFG.RewardForKey(kl)
  if r then
    local lines = {}
    lines[#lines + 1] = string.format(L.PREVIEW_ENDOFRUN_FMT, r.endI, Tier(r.endT), r.endR)
    lines[#lines + 1] = string.format(L.PREVIEW_VAULT_FMT, r.vaultI, Tier(r.vaultT), r.vaultR)
    if r.crest then
      lines[#lines + 1] = string.format(L.PREVIEW_CREST_FMT, r.crest, Tier(r.crestT))
    end
    panel.reward:SetText(table.concat(lines, "\n"))
  else
    panel.reward:SetText("")
  end

  -- checkboxes
  for _, c in ipairs(dchecks) do
    if c.label and KLFG.DungeonName then c.label:SetText(KLFG.DungeonName(c.cm)) end
    if KLFG.IsDungeonSelected then c:SetChecked(KLFG.IsDungeonSelected(c.cm)) end
  end
end

-- ---------------------------------------------------------------------------
-- show/hide: aparece quando o painel de BUSCA nativo de MASMORRAS está ativo
-- ---------------------------------------------------------------------------
local DUNGEON_CAT = 2

local function ShouldShow()
  local lf = _G.LFGListFrame
  if not (lf and lf:IsShown()) then return false end
  local sp = lf.SearchPanel
  if not (sp and sp:IsShown()) then return false end
  -- só pra categoria de masmorras (M+)
  if sp.categoryID ~= nil and sp.categoryID ~= DUNGEON_CAT then return false end
  return true
end

local function Refresh()
  if ShouldShow() then
    BuildPanel()
    if panel then
      UpdateContent()
      panel:Show()
    end
  elseif panel then
    panel:Hide()
  end
end

-- Hook do UpdateResultList nativo: a Blizzard acabou de popular self.results com a
-- lista CHEIA. Cacheamos e aplicamos nosso filtro de dungeon (re-render). Só
-- re-renderiza (UpdateResults), nunca re-busca → sem throttle/vermelho.
local function OnResultList(self)
  lastFull = (self and type(self.results) == "table") and self.results or {}
  FilterCurrentResults()
  Refresh()
end

-- atualiza conteúdo quando a config muda (chave/dungeons/liga). O bus chama todos
-- os callbacks com o nome do evento; reagimos a "config".
if KLFG.bus and KLFG.bus.Register then
  KLFG.bus:Register(function(event, arg)
    if event == "config" and panel and panel:IsShown() then UpdateContent() end
    -- "loot" (drops chegaram async pro cm=arg): re-popula a tira daquela dungeon
    if event == "loot" and built then
      for _, c in ipairs(dchecks) do
        if c.row and c.row.cm == arg then PopulateDrops(c.row) end
      end
    end
  end)
end

-- segue show/hide do finder nativo (mesmos ganchos do PGF), instalados quando o
-- Blizzard_GroupFinder carrega
local hooked = false
local function InstallHooks()
  if hooked then return end
  if type(_G.LFGListSearchPanel_SetCategory) ~= "function" then return end
  hooked = true
  hooksecurefunc("LFGListSearchPanel_SetCategory", Refresh)
  if type(_G.LFGListFrame_SetActivePanel) == "function" then
    hooksecurefunc("LFGListFrame_SetActivePanel", Refresh)
  end
  if type(_G.LFGListSearchPanel_UpdateResultList) == "function" then
    hooksecurefunc("LFGListSearchPanel_UpdateResultList", OnResultList)
  end
  if _G.PVEFrame then
    _G.PVEFrame:HookScript("OnShow", Refresh)
    _G.PVEFrame:HookScript("OnHide", Refresh)
  end
  Refresh()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, e, name)
  if (e == "ADDON_LOADED" and name == "Blizzard_GroupFinder") or e == "PLAYER_LOGIN" then
    InstallHooks()
  end
end)
InstallHooks()
