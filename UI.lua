-- KrononLFG — UI: moldura nativa (ButtonFrameTemplate) com a logo do Kronon no
-- portrait, roteador de views (Ligas / Lupa / Resultados / Config), cards de Liga,
-- painel de resultados 1-a-1 e tooltip de drops. Reusa o padrão visual do
-- KrononAlts (paleta + ButtonFrameTemplate + fallback BackdropTemplate).
--
-- ⚠️ As ações PROTEGIDAS (KLFG.Search / ApplyToCurrent / CreateMyGroup /
-- RemoveMyGroup) só são chamadas DENTRO de OnClick de clique humano — ver os
-- botões "Procurar", "Inscrever-se" e "Criar meu grupo" abaixo. Nenhum timer/
-- OnUpdate/:Click() programático aciona essas funções.

local KLFG = KrononLFG
local L = KLFG.L

-- ---------------------------------------------------------------------------
-- Paleta "premium" (espírito Fellowship) + helpers de estilo defensivos:
-- navy quase-preto + acento ouro/âmbar (títulos/CTA/bordas ativas) +
-- teal/ciano (divisórias/abas). Papéis com cor fixa em toda a UI.
-- ---------------------------------------------------------------------------
local BG          = { 0.063, 0.094, 0.141 } -- navy #101824 (painéis)
local BG_DEEP     = { 0.047, 0.063, 0.094 } -- underlay quase-preto #0c1018
local PANEL       = { 0.082, 0.114, 0.165 } -- painel um tom acima do navy
local ACCENT      = { 0.851, 0.678, 0.353 } -- ouro/âmbar #d9ad5a
local ACCENT_HOT  = { 1.00, 0.85, 0.55 }    -- âmbar claro (hover/realce de borda)
local TEAL        = { 0.247, 0.714, 0.788 } -- ciano #3fb6c9 (divisórias/abas)
local ACCENT_BLUE = { 0.20, 0.60, 1.00 }
local COLOR_DONE    = { 0.24, 0.78, 0.46 }
local COLOR_MISSING = { 0.52, 0.55, 0.62 }
local COLOR_ACTION  = { 0.851, 0.678, 0.353 } -- CTA âmbar (elemento mais brilhante)
local TEXT_ON_GOLD  = { 0.10, 0.07, 0.02 }    -- texto escuro p/ ler sobre âmbar
-- Papéis (consistente em TODA a UI): Tanque azul · Curador verde · DPS vermelho.
local ROLE_TANK   = { 0.31, 0.56, 0.95 }
local ROLE_HEALER = { 0.30, 0.80, 0.45 }
local ROLE_DPS    = { 0.86, 0.33, 0.33 }
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local LOGO   = "Interface\\AddOns\\KrononLFG\\Media\\KrononLogo.tga"

local function RoleColor(which)
  if which == "tank" then return ROLE_TANK end
  if which == "healer" then return ROLE_HEALER end
  return ROLE_DPS
end

local FRAME_W, FRAME_H = 720, 486
local BOTTOM_H = 46

-- design system: reusa KA.STYLE se o KrononAlts estiver presente, senão cópia local
local STYLE_FALLBACK = {
  bgRow    = { 0, 0, 0, 0.16 },
  divider  = { 1, 1, 1, 0.07 },
  titlebar = { 0.10, 0.10, 0.10, 1 },
  card     = { 0, 0, 0, 0.12 },
  tabActive= { 1, 1, 1, 0.06 },
}
local function Style()
  local ka = KLFG.GetKA and KLFG.GetKA()
  if ka and type(ka.STYLE) == "table" then return ka.STYLE end
  return STYLE_FALLBACK
end
local function StyleColor(key, fb)
  local c = (Style()[key]) or fb
  return c or { 0, 0, 0, 0 }
end
local function ApplyStyleTex(tex, key, fb)
  if not tex then return end
  local c = StyleColor(key, fb)
  tex:SetColorTexture(c[1] or 0, c[2] or 0, c[3] or 0, c[4])
end

local function FormatAge(sec)
  sec = tonumber(sec) or 0
  if sec < 60 then return sec .. "s" end
  local m = math.floor(sec / 60)
  if m < 60 then return m .. "m" end
  local h = math.floor(m / 60)
  return h .. "h " .. (m % 60) .. "m"
end

-- ---------------------------------------------------------------------------
-- Posição persistida (KrononLFGDB.pos)
-- ---------------------------------------------------------------------------
local function ApplyPosition(f)
  f:ClearAllPoints()
  local db = KLFG.GetDB and KLFG.GetDB()
  local p = db and db.pos
  if type(p) == "table" and p.point then
    f:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
end
local function SavePosition(f)
  local db = KLFG.GetDB and KLFG.GetDB()
  if not db then return end
  local point, _, relPoint, x, y = f:GetPoint()
  db.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

-- ---------------------------------------------------------------------------
-- Estado de módulo + forward-declarations (referência mútua entre as views)
-- ---------------------------------------------------------------------------
local frame, host, content, bottomBar
local views = {}
local currentView
local bbSearch, bbGear, bbBack, bbEta, bbStatus
local keyBtnPool = {}
local tooltipCM, tooltipOwner
local lastError -- mensagem da última falha de busca (limpa ao iniciar nova busca)

local BuildFrame, ShowView, UpdateBottomBar, EnsureViews
local BuildLeaguesView, RenderLeagues
local BuildMagnifierView, RenderMagnifier
local BuildResultsView, RenderResults
local BuildConfigView, RenderConfig
local ShowDropTooltip

-- ---------------------------------------------------------------------------
-- Pequenas fábricas de widgets
-- ---------------------------------------------------------------------------
local function FlatButton(parent, w, h, label, col, fontObj)
  col = col or { 0.18, 0.20, 0.24 }
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  if b.SetBackdrop then
    pcall(b.SetBackdrop, b, { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 })
    pcall(b.SetBackdropColor, b, col[1], col[2], col[3], 0.9)
    pcall(b.SetBackdropBorderColor, b, 0, 0, 0, 1)
  end
  local fs = b:CreateFontString(nil, "OVERLAY", fontObj or "GameFontNormal")
  fs:SetPoint("CENTER")
  fs:SetText(label or "")
  b.text = fs
  b._col = col
  b:SetScript("OnEnter", function(self)
    if self:IsEnabled() then pcall(self.SetBackdropColor, self, col[1] + 0.08, col[2] + 0.08, col[3] + 0.08, 1) end
  end)
  b:SetScript("OnLeave", function(self)
    pcall(self.SetBackdropColor, self, col[1], col[2], col[3], 0.9)
  end)
  return b
end

local function MakeCheck(parent, label)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("LEFT", c, "RIGHT", 2, 0)
  t:SetText(label or "")
  c.label = t
  return c
end

local function MakeFS(parent, fontObj, text, col)
  local fs = parent:CreateFontString(nil, "OVERLAY", fontObj or "GameFontHighlight")
  fs:SetText(text or "")
  if col then fs:SetTextColor(col[1], col[2], col[3]) end
  return fs
end

-- sombra discreta em títulos (look serifado dourado mais legível sobre navy)
local function Titlize(fs)
  if not fs then return fs end
  pcall(fs.SetShadowColor, fs, 0, 0, 0, 0.9)
  pcall(fs.SetShadowOffset, fs, 1, -1)
  return fs
end

-- só aplica um atlas se ele EXISTIR (evita textura/janela invisível). Sem API → false.
local function HasAtlas(name)
  if C_Texture and C_Texture.GetAtlasInfo then
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
  end
  return false
end

-- emblema defensivo: tenta atlas validados (escudo/medalha), cai pra ícone garantido,
-- e em último caso uma cor sólida. NUNCA deixa a textura invisível.
local function SetEmblem(tex, atlasList, iconFallback, color)
  if type(atlasList) == "table" then
    for _, a in ipairs(atlasList) do
      if HasAtlas(a) and pcall(tex.SetAtlas, tex, a, true) then return true end
    end
  end
  if iconFallback and pcall(tex.SetTexture, tex, iconFallback) then return true end
  if color then tex:SetColorTexture(color[1], color[2], color[3], 0.4) end
  return false
end

-- realça um botão como CTA dominante: glow âmbar atrás (estático, ADD) + bisel.
local function StyleCTA(b)
  if not b then return end
  local glow = b:CreateTexture(nil, "BACKGROUND", nil, -1)
  glow:SetPoint("TOPLEFT", b, "TOPLEFT", -10, 10)
  glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 10, -10)
  glow:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.22)
  glow:SetBlendMode("ADD")
  b.glow = glow
  local top = b:CreateTexture(nil, "OVERLAY")
  top:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
  top:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
  top:SetHeight(1); top:SetColorTexture(1, 1, 1, 0.25)
  local bot = b:CreateTexture(nil, "OVERLAY")
  bot:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
  bot:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  bot:SetHeight(1); bot:SetColorTexture(0, 0, 0, 0.35)
  if b.text then b.text:SetTextColor(TEXT_ON_GOLD[1], TEXT_ON_GOLD[2], TEXT_ON_GOLD[3]) end
end

-- badge compacto: fundo escuro arredondado + texto ouro (ilvl no canto).
local function MakeBadge(parent, fontObj)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetSize(54, 18)
  if f.SetBackdrop then
    pcall(f.SetBackdrop, f, { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 })
    pcall(f.SetBackdropColor, f, 0, 0, 0, 0.65)
    pcall(f.SetBackdropBorderColor, f, ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
  end
  local fs = f:CreateFontString(nil, "OVERLAY", fontObj or "GameFontNormalSmall")
  fs:SetPoint("CENTER")
  fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
  f.text = fs
  return f
end

-- slot de papel: quadrado preenchido (vaga ocupada) vs contorno (vaga aberta).
-- s.hl = glow âmbar externo, ligado quando é o MEU papel.
local function MakeRoleSlot(parent, which, size)
  size = size or 22
  local s = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  s:SetSize(size, size)
  if s.SetBackdrop then
    pcall(s.SetBackdrop, s, { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 2 })
  end
  s.role = which
  local hl = parent:CreateTexture(nil, "BACKGROUND")
  hl:SetPoint("TOPLEFT", s, "TOPLEFT", -3, 3)
  hl:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 3, -3)
  hl:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.55)
  hl:SetBlendMode("ADD")
  hl:Hide()
  s.hl = hl
  return s
end

-- estado de um slot: filled = cor cheia do papel; vazio = fundo escuro + contorno.
local function SetSlotState(s, filled, mine)
  if not s then return end
  local c = RoleColor(s.role)
  if filled then
    pcall(s.SetBackdropColor, s, c[1], c[2], c[3], 0.95)
    pcall(s.SetBackdropBorderColor, s, math.min(c[1] + 0.2, 1), math.min(c[2] + 0.2, 1), math.min(c[3] + 0.2, 1), 1)
  else
    pcall(s.SetBackdropColor, s, c[1] * 0.18, c[2] * 0.18, c[3] * 0.18, 0.5)
    pcall(s.SetBackdropBorderColor, s, c[1], c[2], c[3], 0.85)
  end
  if s.hl then s.hl:SetShown(mine and true or false) end
end

-- pinta os 5 slots (tank, healer, dps×3) a partir de counts + papel do jogador.
local function RenderResultSlots(v, counts, role)
  if not (v and v.slots) then return end
  counts = counts or {}
  role = role or {}
  local t = counts.TANK or 0
  local h = counts.HEALER or 0
  local d = counts.DAMAGER or 0
  local filled = { t >= 1, h >= 1, d >= 1, d >= 2, d >= 3 }
  local mine   = { role.tank, role.healer, role.damager, role.damager, role.damager }
  for i, s in ipairs(v.slots) do
    s:Show()
    SetSlotState(s, filled[i], mine[i])
  end
end

local function HideResultSlots(v)
  if not (v and v.slots) then return end
  for _, s in ipairs(v.slots) do s:Hide() end
end

-- ---------------------------------------------------------------------------
-- Construção da moldura (ButtonFrameTemplate + fallback) — padrão do KrononAlts
-- ---------------------------------------------------------------------------
BuildFrame = function()
  if frame then return end

  local usingTemplate = false
  do
    local ok = pcall(function()
      frame = CreateFrame("Frame", "KrononLFGFrame", UIParent, "ButtonFrameTemplate")
    end)
    if ok and frame and frame.Inset then
      usingTemplate = true
    else
      frame = CreateFrame("Frame", "KrononLFGFrame", UIParent, "BackdropTemplate")
    end
  end
  frame:SetSize(FRAME_W, FRAME_H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  ApplyPosition(frame)

  host = (usingTemplate and frame.Inset) or frame
  frame.host = host

  -- underlay opaco navy (nada da cena vaza atrás do conteúdo)
  local solidBg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  solidBg:SetAllPoints()
  solidBg:SetColorTexture(BG_DEEP[1], BG_DEEP[2], BG_DEEP[3], 1)

  if usingTemplate then
    pcall(function()
      if frame.SetTitle then frame:SetTitle(L.TITLE)
      elseif frame.TitleText then frame.TitleText:SetText(L.TITLE) end
    end)
    pcall(function()
      local p = (frame.PortraitContainer and frame.PortraitContainer.portrait) or frame.portrait or frame.Portrait
      if p then
        p:SetTexture(LOGO)
        p:SetTexCoord(-0.08, 1.08, -0.08, 1.08)
      end
    end)
    if frame.CloseButton then
      frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    end
    -- arraste por handle sobre a titlebar (deixa o X livre à direita)
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, 0)
    drag:SetHeight(36)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition(frame) end)
  else
    -- fallback manual: backdrop + titlebar com logo e arraste
    if frame.SetBackdrop then
      pcall(frame.SetBackdrop, frame, {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = WHITE8, edgeSize = 1,
      })
      pcall(frame.SetBackdropColor, frame, 0.07, 0.08, 0.10, 1)
      pcall(frame.SetBackdropBorderColor, frame, 0, 0, 0, 1)
    end
    local tb = CreateFrame("Frame", nil, frame)
    tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(30)
    tb:EnableMouse(true); tb:RegisterForDrag("LeftButton")
    tb:SetScript("OnDragStart", function() frame:StartMoving() end)
    tb:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition(frame) end)
    local tbbg = tb:CreateTexture(nil, "BACKGROUND")
    tbbg:SetAllPoints(); ApplyStyleTex(tbbg, "titlebar", { 0.10, 0.10, 0.10, 1 })
    local tbicon = tb:CreateTexture(nil, "ARTWORK")
    tbicon:SetSize(20, 20); tbicon:SetPoint("LEFT", tb, "LEFT", 6, 0)
    if not pcall(function() tbicon:SetTexture(LOGO); tbicon:SetTexCoord(-0.08, 1.08, -0.08, 1.08) end) then
      tbicon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    end
    local title = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", tbicon, "RIGHT", 6, 0); title:SetText(L.TITLE)
    local close = CreateFrame("Button", nil, tb, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", tb, "TOPRIGHT", 2, 4)
    close:SetScript("OnClick", function() frame:Hide() end)
  end

  pcall(function() tinsert(UISpecialFrames, "KrononLFGFrame") end) -- ESC fecha

  -- área de conteúdo + barra inferior
  content = CreateFrame("Frame", nil, host)
  content:SetPoint("TOPLEFT", host, "TOPLEFT", 8, usingTemplate and -6 or -34)
  content:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, BOTTOM_H + 6)
  -- leve tom navy sobre a área de conteúdo (look premium sobre o template)
  local cbg = content:CreateTexture(nil, "BACKGROUND", nil, -7)
  cbg:SetAllPoints(); cbg:SetColorTexture(BG[1], BG[2], BG[3], 0.35)

  bottomBar = CreateFrame("Frame", nil, host)
  bottomBar:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 8, 6)
  bottomBar:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 6)
  bottomBar:SetHeight(BOTTOM_H)
  local bbBg = bottomBar:CreateTexture(nil, "BACKGROUND")
  bbBg:SetAllPoints(); bbBg:SetColorTexture(PANEL[1], PANEL[2], PANEL[3], 0.6)
  -- divisória teal no topo da barra (acento ciano)
  local bbLine = bottomBar:CreateTexture(nil, "ARTWORK")
  bbLine:SetPoint("TOPLEFT"); bbLine:SetPoint("TOPRIGHT"); bbLine:SetHeight(1)
  bbLine:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.5)

  -- Voltar (esquerda)
  bbBack = FlatButton(bottomBar, 80, 28, L.BTN_BACK, { 0.16, 0.18, 0.22 })
  bbBack:SetPoint("LEFT", bottomBar, "LEFT", 6, 0)
  bbBack:SetScript("OnClick", function() ShowView("leagues") end)

  -- Procurar (centro) — ⚠️ HARDWARE EVENT: aciona KLFG.Search direto no OnClick.
  -- CTA dominante: âmbar biselado, largo, com leve glow (StyleCTA). Resto minimalista.
  bbSearch = FlatButton(bottomBar, 224, 34, L.BTN_SEARCH, COLOR_ACTION, "GameFontNormalLarge")
  bbSearch:SetPoint("CENTER", bottomBar, "CENTER", 0, 0)
  StyleCTA(bbSearch)
  bbSearch:SetScript("OnClick", function()
    local ok = KLFG.Search()
    ShowView("results")
    if not ok then RenderResults() end
  end)

  -- ETA / status (à esquerda do centro)
  bbEta = MakeFS(bottomBar, "GameFontDisableSmall", "", COLOR_MISSING)
  bbEta:SetPoint("RIGHT", bbSearch, "LEFT", -10, 0)

  -- Engrenagem (direita)
  bbGear = FlatButton(bottomBar, 90, 28, L.TAB_CONFIG, { 0.16, 0.18, 0.22 })
  bbGear:SetPoint("RIGHT", bottomBar, "RIGHT", -6, 0)
  bbGear:SetScript("OnClick", function() ShowView("config") end)

  EnsureViews()
  ShowView("leagues")
  -- frames nascem visíveis; esconder pra que o 1º Toggle/Open ABRA (e não feche)
  frame:Hide()
end

EnsureViews = function()
  if not views.leagues then BuildLeaguesView() end
  if not views.magnifier then BuildMagnifierView() end
  if not views.results then BuildResultsView() end
  if not views.config then BuildConfigView() end
end

-- ---------------------------------------------------------------------------
-- Roteador de views
-- ---------------------------------------------------------------------------
ShowView = function(name)
  currentView = name
  EnsureViews()
  for vn, vf in pairs(views) do
    if vf then vf:SetShown(vn == name) end
  end
  UpdateBottomBar()
  if name == "leagues" then RenderLeagues()
  elseif name == "magnifier" then RenderMagnifier()
  elseif name == "results" then RenderResults()
  elseif name == "config" then RenderConfig() end
end

UpdateBottomBar = function()
  if not bottomBar then return end
  bbBack:SetShown(currentView ~= "leagues")
  -- o botão Procurar faz sentido em Ligas/Lupa/Resultados; na Config vira "Pronto"
  if currentView == "config" then
    bbSearch.text:SetText(L.CONFIG_SAVE)
    bbSearch:SetScript("OnClick", function() ShowView("leagues") end)
  else
    bbSearch.text:SetText(currentView == "results" and L.BTN_REFRESH or L.BTN_SEARCH)
    bbSearch:SetScript("OnClick", function()
      local ok = KLFG.Search()
      ShowView("results")
      if not ok then RenderResults() end
    end)
  end
end

-- ===========================================================================
-- VIEW: LIGAS — 3 cards verticais
-- ===========================================================================
BuildLeaguesView = function()
  local v = CreateFrame("Frame", nil, content)
  v:SetAllPoints(content)
  views.leagues = v

  local header = Titlize(MakeFS(v, "GameFontNormalLarge", L.TAB_LEAGUES, ACCENT))
  header:SetPoint("TOP", v, "TOP", 0, -6)

  v.cards = {}
  local n = #KLFG.LEAGUES
  local cardW, cardH, gap = 210, 320, 16
  local totalW = n * cardW + (n - 1) * gap
  for i, lg in ipairs(KLFG.LEAGUES) do
    local card = CreateFrame("Button", nil, v, "BackdropTemplate")
    card:SetSize(cardW, cardH)
    card:SetPoint("TOP", v, "TOP", -totalW / 2 + cardW / 2 + (i - 1) * (cardW + gap), -34)
    if card.SetBackdrop then
      pcall(card.SetBackdrop, card, { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 2 })
      pcall(card.SetBackdropColor, card, PANEL[1], PANEL[2], PANEL[3], 1)
      pcall(card.SetBackdropBorderColor, card, lg.accent[1], lg.accent[2], lg.accent[3], 0.7)
    end

    -- glow de hover (âmbar, ADD), escondido por padrão
    local glow = card:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetPoint("TOPLEFT", card, "TOPLEFT", -8, 8)
    glow:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 8, -8)
    glow:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.18)
    glow:SetBlendMode("ADD")
    glow:Hide()

    -- faixa de identidade no topo (cor-tema da liga) — estandarte vertical em miniatura
    local banner = card:CreateTexture(nil, "ARTWORK")
    banner:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -2)
    banner:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -2)
    banner:SetHeight(5)
    banner:SetColorTexture(lg.accent[1], lg.accent[2], lg.accent[3], 0.95)

    -- vinheta inferior (banda escura) — legibilidade do texto sobre a arte
    local vig = card:CreateTexture(nil, "ARTWORK")
    vig:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 2, 2)
    vig:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -2, 2)
    vig:SetHeight(cardH * 0.5)
    vig:SetColorTexture(0, 0, 0, 0.55)

    -- disco escuro atrás do emblema (dá foco ao brasão)
    local disc = card:CreateTexture(nil, "ARTWORK")
    disc:SetSize(104, 104)
    disc:SetPoint("TOP", card, "TOP", 0, -34)
    disc:SetColorTexture(0, 0, 0, 0.32)

    -- emblema/brasão (atlas de escudo validado → ícone garantido → cor sólida)
    local emblem = card:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(90, 90)
    emblem:SetPoint("CENTER", disc, "CENTER", 0, 0)
    SetEmblem(emblem,
      { "challenges-medal-gold", "UI-Achievement-Shield-1", "ChallengeMode-icon-bestseason" },
      "Interface\\Icons\\Achievement_ChallengeMode_Gold", lg.accent)
    pcall(emblem.SetVertexColor, emblem,
      math.min(lg.accent[1] + 0.25, 1), math.min(lg.accent[2] + 0.25, 1), math.min(lg.accent[3] + 0.25, 1))

    -- lupa no canto superior-direito → abre a view Lupa
    local lupa = CreateFrame("Button", nil, card)
    lupa:SetSize(26, 26)
    lupa:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -6)
    local lupaTex = lupa:CreateTexture(nil, "ARTWORK")
    lupaTex:SetAllPoints()
    if not pcall(lupaTex.SetAtlas, lupaTex, "common-search-magnifyingglass", true) then
      lupaTex:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    end
    lupa:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L.TOOLTIP_MAGNIFIER); GameTooltip:Show()
    end)
    lupa:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lupa:SetScript("OnClick", function()
      KLFG.SetLeague(lg.id); ShowView("magnifier")
    end)

    -- título + subtítulo (faixa) + brasão derivado
    local title = Titlize(MakeFS(card, "GameFontNormalLarge", L[lg.titleKey], lg.accent))
    title:SetPoint("BOTTOM", card, "BOTTOM", 0, 64)
    local desc = MakeFS(card, "GameFontHighlightSmall", L[lg.descKey], { 0.85, 0.85, 0.88 })
    desc:SetPoint("BOTTOM", title, "TOP", 0, 4)
    local range = MakeFS(card, "GameFontDisableSmall", "", COLOR_MISSING)
    range:SetPoint("TOP", title, "BOTTOM", 0, -6)
    local crest = MakeFS(card, "GameFontDisableSmall", "", TEAL)
    crest:SetPoint("TOP", range, "BOTTOM", 0, -5)

    card:SetScript("OnEnter", function(self)
      pcall(self.SetBackdropBorderColor, self, ACCENT_HOT[1], ACCENT_HOT[2], ACCENT_HOT[3], 1)
      glow:Show()
    end)
    card:SetScript("OnLeave", function(self)
      local selected = (KLFG.GetLeague() == lg.id)
      pcall(self.SetBackdropBorderColor, self, lg.accent[1], lg.accent[2], lg.accent[3], selected and 1 or 0.7)
      glow:Hide()
    end)
    card:SetScript("OnClick", function()
      KLFG.SetLeague(lg.id); ShowView("magnifier")
    end)

    card.lg = lg
    card.title = title; card.desc = desc; card.range = range; card.crest = crest
    v.cards[i] = card
  end
end

RenderLeagues = function()
  local v = views.leagues
  if not v then return end
  for _, card in ipairs(v.cards) do
    local lg = card.lg
    card.title:SetText(L[lg.titleKey])
    card.desc:SetText(L[lg.descKey])
    local lo, hi = KLFG.LeagueIlvlRange(lg)
    card.range:SetText(string.format(L.LEAGUE_RANGE_FMT, lo, hi, lg.keyLo, lg.keyHi))
    -- brasão DERIVADO do nível de chave representativo (NÃO um tier fixo por liga)
    local rw = KLFG.RewardForKey(KLFG.LeagueRepKey(lg))
    if rw then
      card.crest:SetText(string.format(L.PREVIEW_CREST_FMT, rw.crest, KLFG.TierName(rw.crestT))
        .. "  " .. L.PREVIEW_CREST_DOUBT)
    else
      card.crest:SetText("")
    end
    local selected = (KLFG.GetLeague() == lg.id)
    pcall(card.SetBackdropBorderColor, card,
      lg.accent[1], lg.accent[2], lg.accent[3], selected and 1 or 0.6)
  end
end

-- ===========================================================================
-- VIEW: LUPA — níveis de chave (esquerda) + 8 masmorras (direita)
-- ===========================================================================
BuildMagnifierView = function()
  local v = CreateFrame("Frame", nil, content)
  v:SetAllPoints(content)
  views.magnifier = v

  v.crumb = Titlize(MakeFS(v, "GameFontNormal", "", ACCENT))
  v.crumb:SetPoint("TOPLEFT", v, "TOPLEFT", 4, -6)
  -- divisória teal sob o breadcrumb
  local cline = v:CreateTexture(nil, "ARTWORK")
  cline:SetPoint("TOPLEFT", v, "TOPLEFT", 4, -24)
  cline:SetPoint("TOPRIGHT", v, "TOPRIGHT", -4, -24)
  cline:SetHeight(1); cline:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.35)

  -- coluna esquerda: títulos + container de botões de chave
  local kl = MakeFS(v, "GameFontHighlightSmall", L.SELECT_KEY_LEVEL, { 0.8, 0.8, 0.85 })
  kl:SetPoint("TOPLEFT", v, "TOPLEFT", 6, -30)
  v.keyContainer = CreateFrame("Frame", nil, v)
  v.keyContainer:SetPoint("TOPLEFT", kl, "BOTTOMLEFT", 0, -6)
  v.keyContainer:SetSize(120, 300)

  -- coluna direita: masmorras
  local dl = MakeFS(v, "GameFontHighlightSmall", L.SELECT_DUNGEONS, { 0.8, 0.8, 0.85 })
  dl:SetPoint("TOPLEFT", v, "TOPLEFT", 150, -30)

  v.rows = {}
  local rowW, rowH = 510, 30
  for i, d in ipairs(KLFG.DUNGEON_DATA) do
    local row = CreateFrame("Button", nil, v, "BackdropTemplate")
    row:SetSize(rowW, rowH)
    row:SetPoint("TOPLEFT", v, "TOPLEFT", 150, -48 - (i - 1) * (rowH + 4))
    row._even = (i % 2 == 0)
    if row.SetBackdrop then
      pcall(row.SetBackdrop, row, { bgFile = WHITE8 })
      pcall(row.SetBackdropColor, row, 0, 0, 0, row._even and 0.18 or 0.10)
    end
    -- banner de fundo da masmorra (alpha baixo)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetAlpha(0.35)
    row.bg = bg

    -- realce teal no hover da linha
    row:SetScript("OnEnter", function(self)
      pcall(self.SetBackdropColor, self, TEAL[1] * 0.4, TEAL[2] * 0.4, TEAL[3] * 0.4, 0.28)
    end)
    row:SetScript("OnLeave", function(self)
      pcall(self.SetBackdropColor, self, 0, 0, 0, self._even and 0.18 or 0.10)
    end)

    -- checkbox de seleção
    local chk = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    chk:SetSize(22, 22); chk:SetPoint("LEFT", row, "LEFT", 4, 0)
    chk:SetScript("OnClick", function() KLFG.ToggleDungeon(d.cm); RenderMagnifier() end)
    row.chk = chk

    local nm = MakeFS(row, "GameFontHighlight", "", { 0.95, 0.95, 0.97 })
    nm:SetPoint("LEFT", chk, "RIGHT", 6, 0)
    row.nm = nm

    -- badge de ilvl no canto (texto ouro sobre fundo escuro)
    local badge = MakeBadge(row, "GameFontNormalSmall")
    badge:SetPoint("RIGHT", row, "RIGHT", -66, 0)
    row.badge = badge

    -- botão "olho" → tooltip de drops
    local eye = FlatButton(row, 56, 22, L.BTN_OPEN_PREVIEW, { 0.18, 0.20, 0.26 }, "GameFontNormalSmall")
    eye:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    eye:SetScript("OnEnter", function(self) ShowDropTooltip(self, d.cm) end)
    eye:SetScript("OnLeave", function() GameTooltip:Hide(); tooltipCM = nil; tooltipOwner = nil end)
    eye:SetScript("OnClick", function(self) ShowDropTooltip(self, d.cm) end)
    row.eye = eye

    row.cm = d.cm
    v.rows[i] = row
  end
end

-- (re)cria os botões de nível de chave da faixa da liga atual (pool simples)
local function RebuildKeyButtons(v)
  for _, b in ipairs(keyBtnPool) do b:Hide() end
  local lg = KLFG.GetLeagueById(KLFG.GetLeague())
  local idx = 0
  for lvl = lg.keyLo, lg.keyHi do
    idx = idx + 1
    local b = keyBtnPool[idx]
    if not b then
      b = FlatButton(v.keyContainer, 110, 30, "", { 0.16, 0.18, 0.22 })
      keyBtnPool[idx] = b
    end
    b:SetParent(v.keyContainer)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", v.keyContainer, "TOPLEFT", 0, -(idx - 1) * 34)
    local rw = KLFG.RewardForKey(lvl)
    local ilvl = rw and rw.endI or 0
    b.text:SetText(string.format(L.KEY_LEVEL_FMT .. "   ilvl %d", lvl, ilvl))
    local selected = (KLFG.GetKeyLevel() == lvl)
    local col = selected and COLOR_ACTION or { 0.16, 0.18, 0.22 }
    b._col = col
    pcall(b.SetBackdropColor, b, col[1], col[2], col[3], 0.9)
    -- contraste do rótulo: texto escuro sobre o âmbar selecionado, claro caso contrário
    if selected then
      b.text:SetTextColor(TEXT_ON_GOLD[1], TEXT_ON_GOLD[2], TEXT_ON_GOLD[3])
    else
      b.text:SetTextColor(0.9, 0.9, 0.92)
    end
    b:SetScript("OnClick", function() KLFG.SetKeyLevel(lvl); RenderMagnifier() end)
    b:Show()
  end
end

RenderMagnifier = function()
  local v = views.magnifier
  if not v then return end
  local lg = KLFG.GetLeagueById(KLFG.GetLeague())
  v.crumb:SetText(string.format("%s: %s  >  %s %d  >  %s",
    L.BREADCRUMB_LEAGUE, L[lg.titleKey], L.BREADCRUMB_KEY, KLFG.GetKeyLevel(), L.BREADCRUMB_DUNGEON))

  RebuildKeyButtons(v)

  local rw = KLFG.RewardForKey(KLFG.GetKeyLevel())
  local dropIlvl = rw and rw.endI or 0
  for _, row in ipairs(v.rows) do
    row.nm:SetText(KLFG.DungeonName(row.cm))
    local bgFile = KLFG.DungeonBG(row.cm)
    if bgFile then pcall(row.bg.SetTexture, row.bg, bgFile) else row.bg:SetTexture(nil) end
    row.badge.text:SetText(string.format("ilvl %d", dropIlvl))
    row.chk:SetChecked(KLFG.IsDungeonSelected(row.cm))
  end
end

-- ===========================================================================
-- VIEW: RESULTADOS — carrossel 1-a-1
-- ===========================================================================
BuildResultsView = function()
  local v = CreateFrame("Frame", nil, content)
  v:SetAllPoints(content)
  views.results = v

  -- card grande central
  local card = CreateFrame("Frame", nil, v, "BackdropTemplate")
  card:SetPoint("TOP", v, "TOP", 0, -10)
  card:SetSize(560, 280)
  if card.SetBackdrop then
    pcall(card.SetBackdrop, card, { bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 2 })
    pcall(card.SetBackdropColor, card, PANEL[1], PANEL[2], PANEL[3], 1)
    pcall(card.SetBackdropBorderColor, card, ACCENT[1], ACCENT[2], ACCENT[3], 0.5)
  end
  v.card = card

  v.status = MakeFS(card, "GameFontNormalLarge", "", { 0.85, 0.85, 0.9 })
  v.status:SetPoint("TOP", card, "TOP", 0, -16)

  v.dungeon = Titlize(MakeFS(card, "GameFontNormalHuge", "", ACCENT))
  v.dungeon:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -16)

  v.keyline = MakeFS(card, "GameFontNormal", "", { 0.9, 0.9, 0.95 })
  v.keyline:SetPoint("TOPLEFT", v.dungeon, "BOTTOMLEFT", 0, -6)

  -- composição do grupo: slots de papel (preenchido vs vaga aberta), não texto "3/5"
  v.compLabel = MakeFS(card, "GameFontHighlightSmall", "", { 0.78, 0.80, 0.86 })
  v.compLabel:SetPoint("TOPLEFT", v.keyline, "BOTTOMLEFT", 0, -12)

  local strip = CreateFrame("Frame", nil, card)
  strip:SetPoint("TOPLEFT", v.compLabel, "BOTTOMLEFT", 2, -8)
  strip:SetSize(5 * 26 + 12, 24)
  v.slots = {}
  local slotDefs = { "tank", "healer", "damager", "damager", "damager" }
  for i, role in ipairs(slotDefs) do
    local s = MakeRoleSlot(strip, role, 22)
    local x = (i - 1) * 26
    if i >= 3 then x = x + 12 end -- separa o trio de DPS do tank/healer
    s:SetPoint("LEFT", strip, "LEFT", x, 0)
    v.slots[i] = s
  end
  -- divisória teal entre healer e o trio de DPS
  local sep = strip:CreateTexture(nil, "ARTWORK")
  sep:SetSize(1, 20)
  sep:SetPoint("LEFT", strip, "LEFT", 2 * 26 + 4, 0)
  sep:SetColorTexture(TEAL[1], TEAL[2], TEAL[3], 0.5)
  v.compStrip = strip

  v.leader = MakeFS(card, "GameFontHighlight", "", { 0.85, 0.85, 0.9 })
  v.leader:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", -2, -10)

  v.age = MakeFS(card, "GameFontDisableSmall", "", COLOR_MISSING)
  v.age:SetPoint("TOPLEFT", v.leader, "BOTTOMLEFT", 0, -8)

  v.eta = MakeFS(card, "GameFontHighlightSmall", "", { 0.8, 0.8, 0.85 })
  v.eta:SetPoint("TOPLEFT", v.age, "BOTTOMLEFT", 0, -4)

  v.appstatus = MakeFS(card, "GameFontNormal", "", COLOR_DONE)
  v.appstatus:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 50)

  -- botão "Drops" (tooltip da masmorra do card atual)
  v.drops = FlatButton(card, 70, 24, L.BTN_OPEN_PREVIEW, { 0.18, 0.20, 0.26 }, "GameFontNormalSmall")
  v.drops:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -16)
  v.drops:SetScript("OnEnter", function(self)
    local e = KLFG.CurrentEntry()
    if e and e.cm then ShowDropTooltip(self, e.cm) end
  end)
  v.drops:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- botão grande Inscrever-se — ⚠️ HARDWARE EVENT: ApplyToCurrent direto no OnClick
  v.apply = FlatButton(card, 240, 40, L.BTN_APPLY, COLOR_DONE, "GameFontNormalLarge")
  v.apply:SetPoint("BOTTOM", card, "BOTTOM", 0, 14)
  v.apply:SetScript("OnClick", function() KLFG.ApplyToCurrent() end)

  -- Pular (avança o cursor; NÃO é protegido)
  v.skip = FlatButton(card, 90, 26, L.BTN_SKIP, { 0.16, 0.18, 0.22 })
  v.skip:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
  v.skip:SetScript("OnClick", function() KLFG.SkipCurrent() end)

  v.counter = MakeFS(card, "GameFontDisableSmall", "", COLOR_MISSING)
  v.counter:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 18)

  -- nota: tempo é estimativa do addon
  v.note = MakeFS(v, "GameFontDisableSmall", L.ETA_ESTIMATE_NOTE, COLOR_MISSING)
  v.note:SetPoint("BOTTOM", v, "BOTTOM", 0, 6)
end

RenderResults = function()
  local v = views.results
  if not v then return end

  if KLFG.IsSearching() then
    v.status:SetText(L.RESULT_SEARCHING)
    v.status:Show()
    v.dungeon:SetText(""); v.keyline:SetText(""); v.compLabel:SetText("")
    HideResultSlots(v)
    v.leader:SetText(""); v.age:SetText(""); v.eta:SetText("")
    v.appstatus:SetText(""); v.counter:SetText("")
    v.apply:Hide(); v.skip:Hide(); v.drops:Hide()
    return
  end

  local e = KLFG.CurrentEntry()
  local total = KLFG.GetQueueSize()
  if not e then
    v.status:SetText(lastError or L.RESULT_NO_GROUPS); v.status:Show()
    v.dungeon:SetText(""); v.keyline:SetText(""); v.compLabel:SetText("")
    HideResultSlots(v)
    v.leader:SetText(""); v.age:SetText(""); v.eta:SetText("")
    v.appstatus:SetText(""); v.counter:SetText("")
    v.apply:Hide(); v.skip:Hide(); v.drops:Hide()
    return
  end

  v.status:Hide()
  v.apply:Show(); v.skip:Show(); v.drops:Show()

  local info = e.info
  local role = KLFG.GetRole()
  v.dungeon:SetText(e.cm and KLFG.DungeonName(e.cm) or (info.name or "?"))

  -- nível de chave: tenta extrair "+N" do comentário; senão mostra o requisito de rating
  local lvl = info.comment and tostring(info.comment):match("%+?(%d%d?)")
  local keyTxt = ""
  if lvl then keyTxt = "+" .. lvl end
  if info.requiredDungeonScore and info.requiredDungeonScore > 0 then
    keyTxt = keyTxt .. (keyTxt ~= "" and "   " or "") .. "io " .. info.requiredDungeonScore
  end
  v.keyline:SetText(keyTxt)

  v.compLabel:SetText(L.RESULT_SLOTS_NEED)
  RenderResultSlots(v, e.counts, role)

  local lname = info.leaderName or "?"
  local lscore = info.leaderOverallDungeonScore or 0
  v.leader:SetText(string.format("%s: %s    %s: %d", L.RESULT_LEADER, lname, L.RESULT_LEADER_RATING, lscore))

  v.age:SetText(string.format(L.RESULT_AGE_FMT, FormatAge(info.age)))

  local etaKey = KLFG.EstimateETA(e)
  v.eta:SetText(L.ETA_LABEL .. ": " .. (L[etaKey] or ""))

  v.counter:SetText(string.format(L.RESULT_GROUP_OF_FMT, KLFG.GetCursor(), total))

  if e.applied then
    v.appstatus:SetText(L.APP_PENDING)
  else
    v.appstatus:SetText("")
  end

  -- indicadores leves no estado da espera na barra inferior
  if bbEta then bbEta:SetText((L[etaKey] or "")) end
end

-- ===========================================================================
-- VIEW: CONFIG
-- ===========================================================================
BuildConfigView = function()
  local v = CreateFrame("Frame", nil, content)
  v:SetAllPoints(content)
  views.config = v

  local title = Titlize(MakeFS(v, "GameFontNormalLarge", L.CONFIG_TITLE, ACCENT))
  title:SetPoint("TOP", v, "TOP", 0, -6)

  -- coluna esquerda: modo de masmorras + lista manual
  local autoChk = MakeCheck(v, L.DUNGEONS_MODE_AUTO)
  autoChk:SetPoint("TOPLEFT", v, "TOPLEFT", 10, -34)
  autoChk:SetScript("OnClick", function(self)
    KLFG.SetDungeonMode(self:GetChecked() and "auto" or "manual"); RenderConfig()
  end)
  v.autoChk = autoChk
  local autoHint = MakeFS(v, "GameFontDisableSmall", L.DUNGEONS_AUTO_HINT, COLOR_MISSING)
  autoHint:SetPoint("TOPLEFT", autoChk, "BOTTOMLEFT", 0, -2)
  autoHint:SetWidth(300); autoHint:SetJustifyH("LEFT")

  v.dchecks = {}
  for i, d in ipairs(KLFG.DUNGEON_DATA) do
    local c = MakeCheck(v, "")
    c:SetPoint("TOPLEFT", v, "TOPLEFT", 14, -64 - (i - 1) * 26)
    c:SetScript("OnClick", function() KLFG.ToggleDungeon(d.cm); RenderConfig() end)
    c.cm = d.cm
    v.dchecks[i] = c
  end

  -- coluna direita: papel, nível de chave, crossfaction, auto-accept, solo
  local roleLabel = MakeFS(v, "GameFontHighlightSmall", L.RESULT_SLOTS_NEED, { 0.8, 0.8, 0.85 })
  roleLabel:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -34)

  -- labels coloridos pelo papel (Tanque azul · Curador verde · DPS vermelho)
  local tankChk = MakeCheck(v, L.ROLE_TANK)
  tankChk:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -54)
  tankChk.label:SetTextColor(ROLE_TANK[1], ROLE_TANK[2], ROLE_TANK[3])
  tankChk:SetScript("OnClick", function(self) KLFG.SetRole("tank", self:GetChecked()) end)
  v.tankChk = tankChk
  local healChk = MakeCheck(v, L.ROLE_HEALER)
  healChk:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -80)
  healChk.label:SetTextColor(ROLE_HEALER[1], ROLE_HEALER[2], ROLE_HEALER[3])
  healChk:SetScript("OnClick", function(self) KLFG.SetRole("healer", self:GetChecked()) end)
  v.healChk = healChk
  local dpsChk = MakeCheck(v, L.ROLE_DAMAGER)
  dpsChk:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -106)
  dpsChk.label:SetTextColor(ROLE_DPS[1], ROLE_DPS[2], ROLE_DPS[3])
  dpsChk:SetScript("OnClick", function(self) KLFG.SetRole("damager", self:GetChecked()) end)
  v.dpsChk = dpsChk

  -- stepper de nível de chave
  local keyLabel = MakeFS(v, "GameFontHighlightSmall", L.SELECT_KEY_LEVEL, { 0.8, 0.8, 0.85 })
  keyLabel:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -140)
  local minus = FlatButton(v, 28, 24, "-", { 0.16, 0.18, 0.22 }, "GameFontNormalLarge")
  minus:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", 0, -4)
  minus:SetScript("OnClick", function() KLFG.SetKeyLevel(KLFG.GetKeyLevel() - 1); RenderConfig() end)
  v.keyVal = MakeFS(v, "GameFontNormalLarge", "", ACCENT)
  v.keyVal:SetPoint("LEFT", minus, "RIGHT", 12, 0)
  local plus = FlatButton(v, 28, 24, "+", { 0.16, 0.18, 0.22 }, "GameFontNormalLarge")
  plus:SetPoint("LEFT", minus, "RIGHT", 50, 0)
  plus:SetScript("OnClick", function() KLFG.SetKeyLevel(KLFG.GetKeyLevel() + 1); RenderConfig() end)

  local xfac = MakeCheck(v, L.CROSSFACTION)
  xfac:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -186)
  xfac:SetScript("OnClick", function(self) KLFG.SetCrossFaction(self:GetChecked()) end)
  v.xfac = xfac

  local autoAcc = MakeCheck(v, L.AUTO_ACCEPT)
  autoAcc:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -212)
  autoAcc:SetScript("OnClick", function(self) KLFG.SetAutoAccept(self:GetChecked()) end)
  v.autoAcc = autoAcc

  -- solo: criar/remover anúncio — ⚠️ HARDWARE EVENT
  local soloLabel = MakeFS(v, "GameFontHighlightSmall", L.SOLO_TITLE, { 0.8, 0.8, 0.85 })
  soloLabel:SetPoint("TOPLEFT", v, "TOPLEFT", 360, -244)
  local createBtn = FlatButton(v, 150, 28, L.BTN_CREATE_GROUP, COLOR_ACTION)
  createBtn:SetPoint("TOPLEFT", soloLabel, "BOTTOMLEFT", 0, -4)
  createBtn.text:SetTextColor(TEXT_ON_GOLD[1], TEXT_ON_GOLD[2], TEXT_ON_GOLD[3]) -- texto escuro sobre âmbar
  createBtn:SetScript("OnClick", function() KLFG.CreateMyGroup() end)
  local removeBtn = FlatButton(v, 150, 24, L.BTN_REMOVE_LISTING, { 0.16, 0.18, 0.22 })
  removeBtn:SetPoint("TOPLEFT", createBtn, "BOTTOMLEFT", 0, -4)
  removeBtn:SetScript("OnClick", function() KLFG.RemoveMyGroup() end)
  local soloHint = MakeFS(v, "GameFontDisableSmall", L.SOLO_HINT, COLOR_MISSING)
  soloHint:SetPoint("TOPLEFT", removeBtn, "BOTTOMLEFT", 0, -4)
  soloHint:SetWidth(300); soloHint:SetJustifyH("LEFT")
end

RenderConfig = function()
  local v = views.config
  if not v then return end
  local auto = (KLFG.GetDungeonMode() == "auto")
  v.autoChk:SetChecked(auto)
  for _, c in ipairs(v.dchecks) do
    c.label:SetText(KLFG.DungeonName(c.cm))
    c:SetChecked(KLFG.IsDungeonSelected(c.cm))
    if auto then c:Disable() else c:Enable() end
  end
  local role = KLFG.GetRole()
  v.tankChk:SetChecked(role.tank)
  v.healChk:SetChecked(role.healer)
  v.dpsChk:SetChecked(role.damager)
  v.keyVal:SetText(string.format(L.KEY_LEVEL_FMT, KLFG.GetKeyLevel()))
  v.xfac:SetChecked(KLFG.GetCrossFaction())
  v.autoAcc:SetChecked(KLFG.GetAutoAccept())
end

-- ===========================================================================
-- Tooltip de drops (drop-preview)
-- ===========================================================================
ShowDropTooltip = function(owner, cm)
  tooltipCM = cm; tooltipOwner = owner
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(KLFG.DungeonName(cm), ACCENT[1], ACCENT[2], ACCENT[3])

  local kl = KLFG.GetKeyLevel()
  local rw = KLFG.Loot.RewardInfo(kl)
  local dropIlvl = rw and rw.endI or 0
  if rw then
    -- ilvl como badge à direita (ouro); fim da run realçado
    GameTooltip:AddDoubleLine(string.format(L.PREVIEW_ENDOFRUN_FMT, rw.endI, KLFG.TierName(rw.endT), rw.endR),
      string.format("ilvl %d", rw.endI), ACCENT[1], ACCENT[2], ACCENT[3], ACCENT[1], ACCENT[2], ACCENT[3])
    GameTooltip:AddDoubleLine(string.format(L.PREVIEW_VAULT_FMT, rw.vaultI, KLFG.TierName(rw.vaultT), rw.vaultR),
      string.format("ilvl %d", rw.vaultI), 0.8, 0.8, 1, TEAL[1], TEAL[2], TEAL[3])
    GameTooltip:AddLine(string.format(L.PREVIEW_CREST_FMT, rw.crest, KLFG.TierName(rw.crestT)) .. "  " .. L.PREVIEW_CREST_DOUBT, 0.7, 0.7, 0.7)
  end
  GameTooltip:AddLine(" ")

  local data = KLFG.Loot.GetDrops(cm)
  if KLFG.Loot.IsLoading(cm) and not (data and data.ready) then
    GameTooltip:AddLine(L.PREVIEW_LOADING, 0.6, 0.6, 0.6)
  elseif not data or data.noData or #data.items == 0 then
    GameTooltip:AddLine(L.PREVIEW_NO_DATA, 0.6, 0.6, 0.6)
  else
    GameTooltip:AddLine(L.PREVIEW_DROPS, ACCENT[1], ACCENT[2], ACCENT[3])
    local shown = 0
    for _, it in ipairs(data.items) do
      if shown >= 14 then break end
      local nm = it.name or ("item:" .. tostring(it.itemID))
      local r, g, b = 0.9, 0.9, 0.9
      if it.itemID and GetItemQualityColor and GetItemInfo then
        local ok, _, _, quality = pcall(GetItemInfo, it.itemID)
        if ok and quality then
          local okc, qr, qg, qb = pcall(GetItemQualityColor, quality)
          if okc and qr then r, g, b = qr, qg, qb end
        end
      end
      local line = nm
      if it.icon then line = "|T" .. it.icon .. ":14:14|t " .. nm end
      -- badge de ilvl no canto direito de cada item (ouro sobre fundo escuro do tooltip)
      if dropIlvl > 0 then
        GameTooltip:AddDoubleLine(line, string.format("ilvl %d", dropIlvl), r, g, b, ACCENT[1], ACCENT[2], ACCENT[3])
      else
        GameTooltip:AddLine(line, r, g, b)
      end
      shown = shown + 1
    end
    if #data.items > shown then
      GameTooltip:AddLine(string.format("+%d %s", #data.items - shown, L.PREVIEW_OTHER_DROPS), 0.6, 0.6, 0.6)
    end
  end
  GameTooltip:Show()
end

-- loot assíncrono chegou: se o tooltip ainda está aberto na mesma masmorra, atualiza
KLFG.bus:Register(function(kind, cm)
  if kind == "loot" and tooltipCM and cm == tooltipCM and tooltipOwner and GameTooltip:IsShown() then
    ShowDropTooltip(tooltipOwner, tooltipCM)
  end
end)

-- ===========================================================================
-- Reações da UI aos eventos do LFG (re-render do que estiver visível)
-- ===========================================================================
KLFG.bus:Register(function(kind, a, b)
  if not (frame and frame:IsShown()) then return end
  if kind == "searching" or kind == "results" then
    if kind == "searching" then lastError = nil end
    if currentView == "results" then RenderResults() end
  elseif kind == "config" then
    if currentView == "config" then RenderConfig()
    elseif currentView == "magnifier" then RenderMagnifier()
    elseif currentView == "leagues" then RenderLeagues() end
  elseif kind == "app_status" then
    local v = views.results
    if v and v.appstatus then
      local key = b or "APP_PENDING"
      v.appstatus:SetText(L[key] or "")
    end
  elseif kind == "search_error" then
    if a == "no_mplus" then lastError = L.MSG_NO_M_PLUS
    elseif a == "blocked" then lastError = L.MSG_BLOCKED
    else lastError = L.RESULT_NO_GROUPS end
    local v = views.results
    if v and v.status then
      v.status:Show()
      v.status:SetText(lastError)
    end
    -- desabilita o Procurar brevemente (re-habilitar NÃO é protegido)
    if bbSearch then
      bbSearch:Disable()
      if C_Timer and C_Timer.After then C_Timer.After(2, function() if bbSearch then bbSearch:Enable() end end) end
    end
  end
end)

-- ===========================================================================
-- API pública: Toggle / Open / OpenConfig
-- ===========================================================================
function KLFG.Toggle()
  if not frame then BuildFrame() end
  if frame:IsShown() then frame:Hide() else frame:Show(); ShowView(currentView or "leagues") end
end
function KLFG.Open()
  if not frame then BuildFrame() end
  if not frame:IsShown() then frame:Show(); ShowView(currentView or "leagues") end
end
function KLFG.OpenConfig()
  if not frame then BuildFrame() end
  if not frame:IsShown() then frame:Show() end
  ShowView("config")
end

-- ===========================================================================
-- Botão de minimapa (sem libs) — ângulo salvo em KrononLFGDB.minimap
-- ===========================================================================
local minimapBtn
local function UpdateMinimapPosition()
  if not minimapBtn or not Minimap then return end
  local db = KLFG.GetDB and KLFG.GetDB()
  local angle = (db and db.minimap and db.minimap.angle) or 200
  local rad = math.rad(angle)
  local r = 80
  minimapBtn:ClearAllPoints()
  minimapBtn:SetPoint("CENTER", Minimap, "CENTER", r * math.cos(rad), r * math.sin(rad))
end
local function MinimapDragUpdate(self)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  local angle = math.deg(math.atan2(py - my, px - mx))
  local db = KLFG.GetDB and KLFG.GetDB()
  if db and type(db.minimap) == "table" then db.minimap.angle = angle end
  UpdateMinimapPosition()
end

function KLFG.InitMinimap()
  if minimapBtn then UpdateMinimapPosition(); return end
  if not Minimap then return end
  local db = KLFG.GetDB and KLFG.GetDB()
  if db and db.minimap and db.minimap.hide then return end

  local b = CreateFrame("Button", "KrononLFGMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetMovable(true)

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  if not pcall(function() icon:SetTexture(LOGO); icon:SetTexCoord(-0.08, 1.08, -0.08, 1.08) end) then
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
  end
  icon:SetPoint("CENTER", b, "CENTER", -1, 1)

  local overlay = b:CreateTexture(nil, "OVERLAY")
  overlay:SetSize(53, 53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

  b:SetScript("OnClick", function() if KLFG.Toggle then KLFG.Toggle() end end)
  b:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", MinimapDragUpdate) end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.TITLE, ACCENT[1], ACCENT[2], ACCENT[3])
    GameTooltip:AddLine(L.MINIMAP_TOOLTIP, 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  minimapBtn = b
  UpdateMinimapPosition()
end
