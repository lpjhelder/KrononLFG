-- KrononLFG — Loot: drop-preview via Encounter Journal. Lê os itens da masmorra
-- (EJ_SelectInstance + difficulty 23 = Mítico de masmorra), faz cache por
-- challengeModeId, re-enumera quando o loot chega assíncrono
-- (EJ_LOOT_DATA_RECIEVED), e cruza com a KEY_REWARDS pra ilvl/brasão por chave.
--
-- ⚠️ O Encounter Journal usa ESTADO GLOBAL (EJ_SelectInstance/SetDifficulty/Tier).
-- Mexer nele pode atrapalhar o Journal aberto pelo usuário e o loot é assíncrono.
-- Por isso: tudo em pcall, salvamos/restauramos o tier, cacheamos e re-enumeramos
-- no evento. Se nada disso funcionar, degradamos pra "sem dados" (PREVIEW_NO_DATA)
-- em vez de quebrar.
--
-- ⚠️ CM_TO_EJ (challengeModeId -> journalInstanceID) NÃO tem API direta. A
-- resolução primária é por NOME em runtime (casando GetMapUIInfo com as
-- instâncias do EJ). KLFG.CM_TO_EJ (em Core.lua) é só o override hardcoded pra
-- quando o match por nome falhar — PRECISA ser validado in-game. Se errar, o
-- preview fica vazio (não mostra masmorra errada porque casamos por nome).

local KLFG = KrononLFG
local L = KLFG.L

KLFG.Loot = KLFG.Loot or {}
local Loot = KLFG.Loot

-- ---------------------------------------------------------------------------
-- Estado
-- ---------------------------------------------------------------------------
local cache = {}      -- [cm] = { items = {...}, ready = bool, noData = bool }
local EJ_BY_CM = {}   -- [cm] = journalInstanceID (resolvido)
local pendingCM       -- masmorra cujos dados estão carregando (async)
local tries = {}      -- [cm] = nº de re-enumerações (trava anti-loop)

-- ---------------------------------------------------------------------------
-- Resolve o journalInstanceID de um challengeModeId.
--   1) cache  2) override KLFG.CM_TO_EJ (validado in-game)  3) match por nome
-- O match por nome varre os tiers do EJ comparando EJ_GetInstanceByIndex(name)
-- com C_ChallengeMode.GetMapUIInfo(cm). Salva/restaura o tier selecionado.
-- ---------------------------------------------------------------------------
local function ResolveEJ(cm)
  if EJ_BY_CM[cm] then return EJ_BY_CM[cm] end
  if KLFG.CM_TO_EJ and KLFG.CM_TO_EJ[cm] then
    EJ_BY_CM[cm] = KLFG.CM_TO_EJ[cm]
    return EJ_BY_CM[cm]
  end
  if not (EJ_GetInstanceByIndex and EJ_SelectTier and EJ_GetNumTiers) then return nil end

  local name = KLFG.DungeonName(cm)
  if type(name) ~= "string" or name == "" or name:sub(1, 1) == "#" then return nil end
  local nameL = name:lower()

  local prevTier = EJ_GetCurrentTier and EJ_GetCurrentTier() or nil
  local okN, numTiers = pcall(EJ_GetNumTiers)
  if not okN or type(numTiers) ~= "number" then numTiers = 0 end

  local found
  for tier = numTiers, 1, -1 do -- começa do tier mais novo (expansão atual)
    pcall(EJ_SelectTier, tier)
    local idx = 1
    while idx <= 60 do
      local ok, instanceID, instName = pcall(EJ_GetInstanceByIndex, idx, false) -- false = masmorras
      if not ok or not instanceID then break end
      if type(instName) == "string" and instName:lower() == nameL then
        found = instanceID
        break
      end
      idx = idx + 1
    end
    if found then break end
  end

  if prevTier then pcall(EJ_SelectTier, prevTier) end
  if found then EJ_BY_CM[cm] = found end
  return found
end

-- ---------------------------------------------------------------------------
-- Carrega os drops de uma masmorra (estado global do EJ; tudo pcall).
-- ---------------------------------------------------------------------------
local function LoadDrops(cm)
  local ej = ResolveEJ(cm)
  if not ej or not (EJ_SelectInstance and EJ_GetLootInfoByIndex) then
    cache[cm] = { items = {}, ready = false, noData = true }
    return cache[cm]
  end

  pendingCM = cm
  -- salva TODO o estado global do EJ pra restaurar depois (não bagunçar o Journal aberto do usuário):
  -- tier + instância + dificuldade. Todos via getter defensivo (podem não existir no cliente).
  local prevTier = EJ_GetCurrentTier and EJ_GetCurrentTier() or nil
  local prevInst
  do local ok, v = pcall(function() return EJ_GetCurrentInstance and EJ_GetCurrentInstance() end); if ok then prevInst = v end end
  local prevDiff
  do local ok, v = pcall(function() return EJ_GetDifficulty and EJ_GetDifficulty() end); if ok then prevDiff = v end end

  local okSel = pcall(EJ_SelectInstance, ej)
  if EJ_SetDifficulty then pcall(EJ_SetDifficulty, 23) end -- Mítico de masmorra
  -- sem filtro de classe/spec: queremos TODOS os drops
  if EJ_ResetLootFilter then pcall(EJ_ResetLootFilter) end

  local n = 0
  if EJ_GetNumLoot then
    local okC, c = pcall(EJ_GetNumLoot)
    if okC and type(c) == "number" then n = c end
  end
  if n <= 0 then n = 250 end -- fallback: itera até dar nil

  local items = {}
  if okSel then
    local i = 1
    while i <= n do
      local ok, info = pcall(EJ_GetLootInfoByIndex, i)
      if not ok or type(info) ~= "table" or not (info.itemID or info.link or info.name) then break end
      items[#items + 1] = {
        itemID = info.itemID, name = info.name, icon = info.icon,
        slot = info.slot, armorType = info.armorType, link = info.link,
        encounterID = info.encounterID,
      }
      i = i + 1
    end
  end

  -- restaura o estado do EJ na ordem certa: tier -> instância -> dificuldade
  if prevTier and EJ_SelectTier then pcall(EJ_SelectTier, prevTier) end
  if prevInst and prevInst ~= 0 and EJ_SelectInstance then pcall(EJ_SelectInstance, prevInst) end
  if prevDiff and EJ_SetDifficulty then pcall(EJ_SetDifficulty, prevDiff) end

  local ready = #items > 0
  cache[cm] = { items = items, ready = ready, noData = (not ready) and (not okSel) }
  if ready then pendingCM = nil end
  return cache[cm]
end

-- ---------------------------------------------------------------------------
-- API pública do drop-preview
-- ---------------------------------------------------------------------------
function Loot.GetDrops(cm)
  if not cm then return nil end
  local c = cache[cm]
  if c and c.ready then return c end
  return LoadDrops(cm)
end

function Loot.IsLoading(cm)
  return pendingCM == cm and not (cache[cm] and cache[cm].ready)
end

function Loot.Invalidate(cm)
  if cm then cache[cm] = nil; tries[cm] = nil else cache = {}; tries = {} end
end

-- Recompensa por nível de chave (ilvl + tier de fim de run / cofre / brasão).
-- Os nomes de tier já vêm localizados. crest fica com selo "a confirmar" na UI.
function Loot.RewardInfo(keyLevel)
  local r = KLFG.RewardForKey(keyLevel)
  if not r then return nil end
  return {
    endI = r.endI, endTcode = r.endT, endT = KLFG.TierName(r.endT), endR = r.endR,
    vaultI = r.vaultI, vaultTcode = r.vaultT, vaultT = KLFG.TierName(r.vaultT), vaultR = r.vaultR,
    crest = r.crest, crestTcode = r.crestT, crestT = KLFG.TierName(r.crestT),
  }
end

-- ---------------------------------------------------------------------------
-- Loot assíncrono: re-enumera a masmorra pendente quando o EJ avisa que chegou.
-- (a grafia "RECIEVED" é a do próprio cliente). Trava anti-loop por tries.
-- ---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
ev:SetScript("OnEvent", function()
  local cm = pendingCM
  if not cm then return end
  tries[cm] = (tries[cm] or 0) + 1
  if tries[cm] > 6 then pendingCM = nil; return end
  cache[cm] = nil
  local c = LoadDrops(cm)
  KLFG.bus:Fire("loot", cm)
  if c and c.ready then pendingCM = nil end
end)
