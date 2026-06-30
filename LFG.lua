-- KrononLFG — LFG: camada sobre o C_LFGList. Descoberta runtime da categoria de
-- masmorras + activityIDs de Mítica+, busca disparada por clique, leitura LIVRE
-- (ranqueamento), e as ações PROTEGIDAS (ApplyToGroup / CreateListing /
-- RemoveListing) restritas a OnClick de clique humano.
--
-- ⚠️⚠️ REGRA INVIOLÁVEL — FUNÇÕES PROTEGIDAS (hardware event desde 7.2.0):
--   C_LFGList.ApplyToGroup / CreateListing / RemoveListing / ClearSearchResults
--   e a própria Search só funcionam DENTRO da pilha de chamada de um clique
--   humano (OnClick). Chamá-las de C_Timer/OnUpdate/SetScript de timer/:Click()
--   programático gera ADDON_ACTION_BLOCKED e a ação falha SILENCIOSAMENTE.
--   Por isso: KLFG.Search / KLFG.ApplyToCurrent / KLFG.CreateMyGroup /
--   KLFG.RemoveMyGroup só são invocadas pelos OnClick em UI.lua. NÃO há auto-loop.
--   Toda a LEITURA (GetSearchResults/Info/MemberCounts) é livre e roda à vontade.

local KLFG = KrononLFG
local L = KLFG.L

-- ---------------------------------------------------------------------------
-- Estado de sessão
-- ---------------------------------------------------------------------------
local dungeonCat        -- categoryID da categoria "Dungeons" (descoberto, NÃO hardcoded)
local ACTIVITY_BY_CM = {} -- [challengeModeId] = activityID (pra montar a busca)
local CM_BY_ACTIVITY = {} -- [activityID] = challengeModeId (pra ler resultados)
local rankedQueue = {}    -- fila ordenada de grupos (melhor primeiro)
local cursor = 1          -- posição atual no carrossel 1-a-1
local searching = false

-- ---------------------------------------------------------------------------
-- Helpers defensivos de leitura do C_LFGList
-- ---------------------------------------------------------------------------
local function GetActivityInfo(actID)
  if C_LFGList and C_LFGList.GetActivityInfoTable then
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, actID)
    if ok and type(info) == "table" then return info end
  end
  -- fallback bem antigo (retorno posicional): só o que dá pra extrair com segurança
  if C_LFGList and C_LFGList.GetActivityInfo then
    local ok, fullName = pcall(C_LFGList.GetActivityInfo, actID)
    if ok and type(fullName) == "string" then return { fullName = fullName } end
  end
  return nil
end

local function GetCategoryName(catID)
  if not (C_LFGList and C_LFGList.GetCategoryInfo) then return nil end
  local ok, a = pcall(C_LFGList.GetCategoryInfo, catID)
  if not ok then return nil end
  if type(a) == "string" then return a end
  if type(a) == "table" then return a.name end
  return nil
end

-- ---------------------------------------------------------------------------
-- Descoberta da categoria de masmorras + mapeamento challengeModeId -> activityID.
-- Critério: a categoria que CONTÉM atividades com info.isMythicPlusActivity==true.
-- O casamento masmorra<->atividade é por NOME (GetMapUIInfo vs info.fullName),
-- pois não há campo direto de challengeModeId no info da atividade.
-- ---------------------------------------------------------------------------
local function BuildActivityMap()
  if not (C_LFGList and C_LFGList.GetAvailableCategories) then return false end
  local ok, cats = pcall(C_LFGList.GetAvailableCategories)
  if not ok or type(cats) ~= "table" then return false end

  -- nomes (lowercase) das masmorras da season pra casar com fullName das atividades
  local names = {}
  for _, d in ipairs(KLFG.DUNGEON_DATA) do
    local n = KLFG.DungeonName(d.cm)
    names[d.cm] = (type(n) == "string") and n:lower() or ""
  end

  local foundCat, map, rev = nil, {}, {}
  for _, catID in ipairs(cats) do
    local ok2, acts = pcall(C_LFGList.GetAvailableActivities, catID)
    if ok2 and type(acts) == "table" then
      local catHasMplus = false
      for _, actID in ipairs(acts) do
        local info = GetActivityInfo(actID)
        if info and info.isMythicPlusActivity then
          catHasMplus = true
          local full = (type(info.fullName) == "string") and info.fullName:lower() or ""
          if full ~= "" then
            for cm, dn in pairs(names) do
              if dn ~= "" and (full:find(dn, 1, true) or dn:find(full, 1, true)) then
                map[cm] = actID
                rev[actID] = cm
              end
            end
          end
        end
      end
      if catHasMplus then foundCat = catID end
    end
  end

  if foundCat then
    dungeonCat = foundCat
    ACTIVITY_BY_CM = map
    CM_BY_ACTIVITY = rev
    return true
  end
  return false
end

local function EnsureCategory()
  if dungeonCat and next(ACTIVITY_BY_CM) then return true end
  return BuildActivityMap()
end
KLFG.EnsureCategory = EnsureCategory

-- ---------------------------------------------------------------------------
-- Busca NATIVA por nível de chave: escreve "+N" na SearchBox nativa e dispara
-- o DoSearch nativo. O SERVIDOR aplica o filtro de chave (±1) e o resultado já
-- vem filtrado em GetSearchResults (que lemos no evento). É o ÚNICO jeito de
-- filtrar por chave (o nível é ilegível pro addon; só o servidor filtra).
-- Tudo defensivo: se a UI nativa não existir/mudar de nome, retorna false e o
-- KLFG.Search cai no fallback (busca direta, sem filtro de chave).
-- Roda dentro do clique do Procurar (hardware event) → DoSearch é permitido.
-- ---------------------------------------------------------------------------
local function TryNativeKeySearch(keyText, filter)
  if type(keyText) ~= "string" or keyText == "" then return false end
  local load = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
  if load then pcall(load, "Blizzard_GroupFinder") end
  local lf = _G.LFGListFrame
  local panel = lf and lf.SearchPanel
  local box = panel and panel.SearchBox
  if not (panel and box and box.SetText) then return false end
  -- só dirige o nativo se o painel já está ABERTO/inicializado (frio não dispara)
  if panel.IsShown and not panel:IsShown() then return false end
  local cat = dungeonCat or 2
  if _G.LFGListSearchPanel_SetCategory then
    if not pcall(_G.LFGListSearchPanel_SetCategory, panel, cat, filter or 0, 0) then
      panel.categoryID = cat
    end
  else
    panel.categoryID = cat
  end
  box:SetText(keyText)
  if _G.LFGListSearchPanel_DoSearch then
    return (pcall(_G.LFGListSearchPanel_DoSearch, panel)) == true
  end
  return false
end
KLFG.TryNativeKeySearch = TryNativeKeySearch

-- ---------------------------------------------------------------------------
-- Busca (disparada por clique). Tratada como hardware event — NUNCA chamar de
-- timer/OnUpdate. Buscamos a categoria inteira (robusto) e filtramos por
-- masmorra/elegibilidade na LEITURA, que é livre.
-- ---------------------------------------------------------------------------
function KLFG.Search()
  if not (C_LFGList and C_LFGList.Search) then return false end
  if not EnsureCategory() then
    KLFG.bus:Fire("search_error", "no_mplus")
    return false
  end
  pcall(KLFG.SeedRoleFromGame)

  searching = true
  rankedQueue = {}
  cursor = 1
  KLFG.bus:Fire("searching")

  local filter = 0
  if Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentSeason then
    filter = Enum.LFGListFilter.CurrentSeason
  end

  -- BUSCA DIRETA (confiável). A busca nativa por chave está em pesquisa e fica
  -- FORA do Procurar até o mecanismo exato estar provado in-game, pra NUNCA mais
  -- arriscar o Procurar. (TryNativeKeySearch fica definida mas desplugada.)
  local ok = pcall(C_LFGList.Search, dungeonCat, filter)
  if not ok then ok = pcall(C_LFGList.Search, dungeonCat) end
  if not ok then
    searching = false
    KLFG.bus:Fire("search_error", "blocked")
    return false
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Leitura + ranqueamento (LIVRE, sem proteção). Tudo defensivo: campos de
-- GetSearchResultInfo podem ser nil (activityIDs plural 11.0.7+, censored
-- 12.1.0, generalPlaystyle 12.0.0) — nunca assumir.
-- ---------------------------------------------------------------------------
local function ReadResultInfo(id)
  if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return nil end
  local ok, info = pcall(C_LFGList.GetSearchResultInfo, id)
  if ok and type(info) == "table" then return info end
  return nil
end
KLFG.ReadResultInfo = ReadResultInfo

local function MemberCounts(id)
  if not (C_LFGList and C_LFGList.GetSearchResultMemberCounts) then return nil end
  local ok, c = pcall(C_LFGList.GetSearchResultMemberCounts, id)
  if ok and type(c) == "table" then return c end
  return nil
end

-- challengeModeId de um resultado (suporta activityIDs plural e activityID singular)
local function ResultCM(info)
  if type(info.activityIDs) == "table" then
    for _, actID in ipairs(info.activityIDs) do
      if CM_BY_ACTIVITY[actID] then return CM_BY_ACTIVITY[actID] end
    end
  end
  if info.activityID and CM_BY_ACTIVITY[info.activityID] then
    return CM_BY_ACTIVITY[info.activityID]
  end
  return nil
end
KLFG.ResultCM = ResultCM

-- Nível da chave (+N) do grupo. ⚠️ NÃO existe campo direto na API: o líder
-- digita no NOME (e às vezes no comentário, que vem censurado no 12.1). Lemos
-- ambos e tentamos os padrões mais comuns ("+8", "8+", "key 8", "chave 8",
-- "8 spam"). Cap 2-40 evita casar rating (io 2500) ou ruído. nil = desconhecido.
local function ResultKeyLevel(info)
  if type(info) ~= "table" then return nil end
  local hay = ((info.name or "") .. "  " .. (info.comment or "")):lower()
  local lvl = hay:match("%+%s*(%d%d?)")        -- "+8", "+ 8", "m+8"
           or hay:match("(%d%d?)%s*%+")        -- "8+"
           or hay:match("key%s*(%d%d?)")       -- "key 8"
           or hay:match("chave%s*(%d%d?)")     -- "chave 8"
           or hay:match("llave%s*(%d%d?)")     -- "llave 8"
           or hay:match("lvl%s*(%d%d?)")       -- "lvl 8"
           or hay:match("level%s*(%d%d?)")     -- "level 8"
           or hay:match("nivel%s*(%d%d?)")     -- "nivel 8"
           or hay:match("^%s*(%d%d?)[%s%+]")   -- "8 spam" (nº no início)
  lvl = tonumber(lvl)
  if lvl and lvl >= 2 and lvl <= 40 then return lvl end
  return nil
end
KLFG.ResultKeyLevel = ResultKeyLevel

-- O grupo precisa do MEU papel? (counts.TANK/HEALER/DAMAGER são membros já no grupo;
-- comp padrão 1/1/3). counts nil = desconhecido → não descarta.
local function GroupNeedsMyRole(counts, role)
  if not counts then return true end
  local t = counts.TANK or 0
  local h = counts.HEALER or 0
  local d = counts.DAMAGER or 0
  if role.tank and t < 1 then return true end
  if role.healer and h < 1 then return true end
  if role.damager and d < 3 then return true end
  return false
end

-- Elegibilidade: descarta se o requisito de ilvl/rating do grupo está acima do meu.
-- Defensivo: se não der pra ler o meu valor, NÃO descarta.
local function Eligible(info)
  local req = info.requiredItemLevel or 0
  if req > 0 and GetAverageItemLevel then
    local ok, _, equipped = pcall(GetAverageItemLevel)
    if ok and type(equipped) == "number" and equipped > 0 and (equipped + 2) < req then
      return false
    end
  end
  local reqS = info.requiredDungeonScore or 0
  if reqS > 0 and C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
    local ok, mine = pcall(C_ChallengeMode.GetOverallDungeonScore)
    if ok and type(mine) == "number" and mine > 0 and mine < reqS then
      return false
    end
  end
  return true
end

-- Pontuação livre por resultado. Retorna nil = descartar (não precisa do meu papel).
-- prefBonus = bônus pela masmorra ser uma das mais desejadas (ordem da seleção do usuário).
local function ScoreResult(info, counts, role, prefBonus)
  if not GroupNeedsMyRole(counts, role) then return nil end
  local score = 1000
  local num = info.numMembers or 0
  local maxP = info.maxNumPlayers or 5
  if maxP > 0 then score = score + (num / maxP) * 340 end -- perto de encher = melhor fit (dominante)
  local lr = info.leaderOverallDungeonScore or 0
  -- rating do líder: PESO BAIXO de propósito. Rating alta = provável chave alta;
  -- não dá pra ler o nível, então não favorecemos +20 jogando líder forte pro topo.
  -- Fica só como leve desempate de qualidade.
  score = score + math.min(lr / 40, 90)
  local age = info.age or 0
  score = score - (age / 60) -- penaliza listagens velhas (grupo provavelmente travado)
  score = score + (prefBonus or 0) -- masmorra recomendada/mais desejada
  return score
end

local function RebuildQueue()
  searching = false
  rankedQueue = {}
  cursor = 1
  if not (C_LFGList and C_LFGList.GetSearchResults) then KLFG.bus:Fire("results"); return end
  local ok, _, results = pcall(C_LFGList.GetSearchResults)
  if not ok or type(results) ~= "table" then KLFG.bus:Fire("results"); return end

  local role = KLFG.GetRole()
  local wantKey = KLFG.GetKeyLevel()       -- chave selecionada (pref. de ranqueamento)
  local selSet, selOrder = {}, {}
  do
    local sel = KLFG.GetSelectedDungeons()
    local nSel = #sel
    for i, cm in ipairs(sel) do
      selSet[cm] = true
      selOrder[cm] = (nSel - i + 1) * 40 -- 1ª escolhida = maior bônus; decresce na ordem
    end
  end

  for _, id in ipairs(results) do
    local info = ReadResultInfo(id)
    if info and not info.isDelisted and not info.hasSelf then
      local cm = ResultCM(info)
      -- ⚠️ 12.x: o título (name) vem como token protegido |K...|k — o addon NÃO lê
      -- o nível. ResultKeyLevel quase sempre dá nil; serve só pra listagens antigas
      -- legíveis. O nível é EXIBIDO (não filtrado) via info.name cru na UI.
      local rkey = ResultKeyLevel(info)
      -- com cm mapeado: exige estar na seleção. Sem mapeamento: aceita (degrada).
      local pass = (cm == nil) or (selSet[cm] == true)
      if pass and Eligible(info) then
        local counts = MemberCounts(id)
        -- bônus de chave: igual à selecionada sobe MUITO; ±1 sobe um pouco
        local keyBonus = 0
        if rkey == wantKey then keyBonus = 280
        elseif rkey and math.abs(rkey - wantKey) == 1 then keyBonus = 70 end
        local score = ScoreResult(info, counts, role, (cm and selOrder[cm] or 0) + keyBonus)
        if score then
          rankedQueue[#rankedQueue + 1] = { id = id, info = info, counts = counts, cm = cm, key = rkey, score = score }
        end
      end
    end
  end

  table.sort(rankedQueue, function(a, b)
    if a.score == b.score then return (a.info.age or 0) < (b.info.age or 0) end
    return a.score > b.score
  end)
  KLFG.bus:Fire("results")
end

-- ---------------------------------------------------------------------------
-- Acesso à fila (usado pela UI)
-- ---------------------------------------------------------------------------
function KLFG.IsSearching() return searching end
function KLFG.GetQueueSize() return #rankedQueue end
function KLFG.GetCursor() return math.min(cursor, #rankedQueue + 1) end

-- Entrada atual, pulando na EXIBIÇÃO as que ficaram delistadas/com você dentro.
function KLFG.CurrentEntry()
  while rankedQueue[cursor] do
    local e = rankedQueue[cursor]
    local fresh = ReadResultInfo(e.id)
    if fresh then e.info = fresh; e.counts = MemberCounts(e.id) or e.counts end
    if e.info and not e.info.isDelisted and not e.info.hasSelf then return e end
    cursor = cursor + 1
  end
  return nil
end

function KLFG.SkipCurrent()
  cursor = cursor + 1
  KLFG.bus:Fire("results")
end

-- Estimativa de espera (heurística — NÃO há API). Retorna uma CHAVE de i18n.
function KLFG.EstimateETA(entry)
  if not entry or not entry.info then return "ETA_UNKNOWN" end
  local info = entry.info
  local num = info.numMembers or 0
  local maxP = info.maxNumPlayers or 5
  local fill = (maxP > 0) and (num / maxP) or 0
  local role = KLFG.GetRole()
  local roleFast = role.tank or role.healer
  local age = info.age or 0
  if fill >= 0.8 then return roleFast and "ETA_FAST" or "ETA_MEDIUM" end
  if fill >= 0.5 then return roleFast and "ETA_FAST" or "ETA_MEDIUM" end
  if age > 1800 then return "ETA_SLOW" end
  return roleFast and "ETA_MEDIUM" or "ETA_SLOW"
end

-- ---------------------------------------------------------------------------
-- AÇÕES PROTEGIDAS — chamar APENAS de OnClick de clique humano (UI.lua).
-- ---------------------------------------------------------------------------

-- Inscreve no grupo atual da fila. PROTEGIDA (ApplyToGroup). 1 clique = 1 inscrição.
-- Depois avança o cursor (apenas MOSTRA o próximo card; NÃO auto-aplica).
function KLFG.ApplyToCurrent()
  local e = KLFG.CurrentEntry()
  if not e then return false end
  if not (C_LFGList and C_LFGList.ApplyToGroup) then return false end
  local role = KLFG.GetRole()
  local ok = pcall(C_LFGList.ApplyToGroup, e.id, role.tank == true, role.healer == true, role.damager == true)
  if ok then
    e.applied = true
    KLFG.bus:Fire("app_status", e.id, "APP_PENDING")
    cursor = cursor + 1
    KLFG.bus:Fire("results")
    return true
  end
  KLFG.bus:Fire("app_status", e.id, "APP_FAILED")
  return false
end

-- Cancela a inscrição do grupo atual. CancelApplication NÃO é protegida.
function KLFG.CancelCurrentApp()
  local e = rankedQueue[cursor]
  if e and C_LFGList and C_LFGList.CancelApplication then
    pcall(C_LFGList.CancelApplication, e.id)
    KLFG.bus:Fire("app_status", e.id, "APP_FAILED")
  end
end

-- Cria/atualiza a própria listagem (modo solo). PROTEGIDA (CreateListing/RemoveListing).
function KLFG.CreateMyGroup()
  if not (C_LFGList and C_LFGList.CreateListing) then return false end
  if not EnsureCategory() then KLFG.bus:Fire("search_error", "no_mplus"); return false end
  local sel = KLFG.GetSelectedDungeons()
  local cm = sel[1]
  local actID = cm and ACTIVITY_BY_CM[cm]
  if not actID then KLFG.bus:Fire("listing", "failed"); return false end

  local createData = {
    activityIDs = { actID },
    isCrossFactionListing = KLFG.GetCrossFaction(),
    isAutoAccept = KLFG.GetAutoAccept(),
  }

  -- já tem anúncio ativo? prefira UpdateListing (NÃO protegida) a recriar
  if C_LFGList.HasActiveEntryInfo then
    local ok, active = pcall(C_LFGList.HasActiveEntryInfo)
    if ok and active and C_LFGList.UpdateListing then
      local ok2 = pcall(C_LFGList.UpdateListing, createData)
      KLFG.bus:Fire("listing", ok2 and "updated" or "failed")
      return ok2
    end
  end

  local ok = pcall(C_LFGList.CreateListing, createData)
  KLFG.bus:Fire("listing", ok and "created" or "failed")
  return ok
end

function KLFG.RemoveMyGroup()
  if not (C_LFGList and C_LFGList.RemoveListing) then return false end
  local ok = pcall(C_LFGList.RemoveListing)
  KLFG.bus:Fire("listing", ok and "removed" or "failed")
  return ok
end

function KLFG.HasActiveListing()
  if C_LFGList and C_LFGList.HasActiveEntryInfo then
    local ok, active = pcall(C_LFGList.HasActiveEntryInfo)
    if ok then return active == true end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Eventos (todos LEITURA / reação — nada protegido aqui)
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
ev:RegisterEvent("LFG_LIST_SEARCH_FAILED")
ev:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
ev:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
    pcall(RebuildQueue)
  elseif event == "LFG_LIST_SEARCH_FAILED" then
    searching = false
    KLFG.bus:Fire("search_error", "failed")
  elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    -- arg1 = resultID, arg2 = novo status (applied/invited/inviteaccepted/declined/failed/...)
    local s = arg2
    local key = "APP_PENDING"
    if s == "invited" or s == "inviteaccepted" then key = "APP_INVITED"
    elseif s == "declined" or s == "declined_full" or s == "declined_delisted" then key = "APP_DECLINED"
    elseif s == "failed" or s == "timedout" or s == "cancelled" then key = "APP_FAILED"
    elseif s == "applied" then key = "APP_PENDING" end
    KLFG.bus:Fire("app_status", arg1, key)
  elseif event == "LFG_LIST_AVAILABILITY_UPDATE" then
    if not (dungeonCat and next(ACTIVITY_BY_CM)) then pcall(EnsureCategory) end
  end
end)
