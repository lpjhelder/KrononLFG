-- KrononLFG — Core: i18n trilíngue, tabelas de dados (masmorras / recompensas /
-- ligas), SavedVariables, namespace público KrononLFG.* e bridge defensiva para o
-- KrononAlts. O addon é STANDALONE: funciona sem KrononAlts/KrononLib (fallbacks
-- locais de dados e i18n). Só reusa KA.* / KrononLib quando presentes e do tipo certo.
--
-- 5º addon do ecossistema Kronon (Interface 120007 — Midnight Season 1).

local ADDON = "KrononLFG"
local KLFG_PREFIX = "|cff33ff33KrononLFG|r: "

-- ---------------------------------------------------------------------------
-- i18n inline (base EN + overlay ptBR/esES). Mesmo padrão do KrononAlts:
-- começa de EN, aplica overlay do locale, chave inexistente retorna a própria
-- chave (setmetatable __index). Se o KrononLib estiver carregado e expuser
-- NewLocale, usamos a lib; caso contrário, merge manual inline.
-- ---------------------------------------------------------------------------
local EN = {
  TITLE                 = "KrononLFG",
  TAB_LEAGUES           = "Leagues",
  TAB_SEARCH            = "Search",
  TAB_PREVIEW           = "Drops",
  TAB_CONFIG            = "Settings",

  LEAGUE_CHAMPION       = "Champion",
  LEAGUE_HERO           = "Hero",
  LEAGUE_MYTH           = "Myth",
  LEAGUE_CHAMPION_DESC  = "Champion-track drops",
  LEAGUE_HERO_DESC      = "Hero-track drops",
  LEAGUE_MYTH_DESC      = "Myth-track vault",
  LEAGUE_RANGE_FMT      = "ilvl %d-%d   ·   +%d-%d",

  BTN_SEARCH            = "Search",
  BTN_REFRESH           = "Refresh",
  BTN_APPLY             = "Apply",
  BTN_SKIP              = "Skip",
  BTN_CANCEL_APP        = "Cancel application",
  BTN_CREATE_GROUP      = "Create my group",
  BTN_UPDATE_LISTING    = "Update listing",
  BTN_REMOVE_LISTING    = "Remove listing",
  BTN_OPEN_PREVIEW      = "Drops",
  BTN_BACK              = "Back",

  MAGNIFIER_TITLE       = "Browse groups",
  BREADCRUMB_LEAGUE     = "League",
  BREADCRUMB_KEY        = "Key",
  BREADCRUMB_DUNGEON    = "Dungeons",
  KEY_LEVEL_FMT         = "+%d",
  SELECT_KEY_LEVEL      = "Key level",
  SELECT_DUNGEONS       = "Dungeons",
  DUNGEONS_MODE_MANUAL  = "Manual",
  DUNGEONS_MODE_AUTO    = "Auto (KrononAlts)",
  DUNGEONS_AUTO_HINT    = "Picks the dungeons with the best loot for your current character.",

  ROLE_TANK             = "Tank",
  ROLE_HEALER           = "Healer",
  ROLE_DAMAGER          = "DPS",
  CROSSFACTION          = "Cross-faction",
  AUTO_ACCEPT           = "Auto-accept (my group)",

  RESULT_GROUP_OF_FMT   = "Group %d of %d",
  RESULT_NO_GROUPS      = "No matching groups. Try Refresh or widen your dungeons.",
  RESULT_SEARCHING      = "Searching for groups…",
  RESULT_LEADER         = "Leader",
  RESULT_LEADER_RATING  = "Rating",
  RESULT_AGE_FMT        = "Listed %s ago",
  RESULT_SLOTS_NEED     = "Needs",
  RESULT_FULL           = "Full",
  RESULT_DELISTED       = "Delisted",

  APP_PENDING           = "Application pending…",
  APP_ACCEPTED          = "Accepted!",
  APP_DECLINED          = "Declined",
  APP_INVITED           = "Invited!",
  APP_FAILED            = "Application failed",

  ETA_LABEL             = "Est. wait",
  ETA_FAST              = "< 1 min",
  ETA_MEDIUM            = "1-5 min",
  ETA_SLOW              = "5+ min",
  ETA_UNKNOWN           = "may take a while",
  ETA_ESTIMATE_NOTE     = "addon estimate, not Blizzard data",

  PREVIEW_DROPS         = "Drops",
  PREVIEW_OTHER_DROPS   = "Other drops",
  PREVIEW_ENDOFRUN_FMT  = "End of run: %d (%s %s)",
  PREVIEW_VAULT_FMT     = "Vault: %d (%s %s)",
  PREVIEW_CREST_FMT     = "Crest: %dx %s",
  PREVIEW_LOADING       = "Loading drops…",
  PREVIEW_NO_DATA       = "No drop data for this dungeon yet.",
  PREVIEW_CREST_DOUBT   = "(to confirm in-game)",

  CREST_CHAMPION        = "Champion",
  CREST_HERO            = "Hero",
  CREST_MYTH            = "Myth",

  SOLO_TITLE            = "Create my own group",
  SOLO_HINT             = "Lists a group for the selected dungeon. One click = one listing.",

  CONFIG_TITLE          = "Settings",
  CONFIG_SAVE           = "Done",

  MSG_NEED_HARDWARE     = "This action must be started by a real mouse click (Blizzard restriction).",
  MSG_BLOCKED           = "Action blocked by the game — click the button directly.",
  MSG_NO_M_PLUS         = "Mythic+ activities not found yet. Open the group finder once and try again.",
  MSG_KA_MISSING        = "KrononAlts not detected — using all dungeons.",
  MSG_EJ_BUSY           = "Drop data is still loading — try again in a moment.",

  TOOLTIP_MAGNIFIER     = "Browse groups for this league",
  MINIMAP_TOOLTIP       = "Left-click to open  ·  drag to move",
  SLASH_HINT            = "/klfg — open  ·  /klfg config — settings",
}

local PT = {
  TAB_LEAGUES           = "Ligas",
  TAB_SEARCH            = "Procurar",
  TAB_PREVIEW           = "Drops",
  TAB_CONFIG            = "Configurações",

  LEAGUE_CHAMPION       = "Campeão",
  LEAGUE_HERO           = "Herói",
  LEAGUE_MYTH           = "Mítico",
  LEAGUE_CHAMPION_DESC  = "Drops da trilha Campeão",
  LEAGUE_HERO_DESC      = "Drops da trilha Herói",
  LEAGUE_MYTH_DESC      = "Cofre da trilha Mítico",
  LEAGUE_RANGE_FMT      = "ilvl %d-%d   ·   +%d-%d",

  BTN_SEARCH            = "Procurar",
  BTN_REFRESH           = "Atualizar",
  BTN_APPLY             = "Inscrever-se",
  BTN_SKIP              = "Pular",
  BTN_CANCEL_APP        = "Cancelar inscrição",
  BTN_CREATE_GROUP      = "Criar meu grupo",
  BTN_UPDATE_LISTING    = "Atualizar anúncio",
  BTN_REMOVE_LISTING    = "Remover anúncio",
  BTN_OPEN_PREVIEW      = "Drops",
  BTN_BACK              = "Voltar",

  MAGNIFIER_TITLE       = "Explorar grupos",
  BREADCRUMB_LEAGUE     = "Liga",
  BREADCRUMB_KEY        = "Chave",
  BREADCRUMB_DUNGEON    = "Masmorras",
  KEY_LEVEL_FMT         = "+%d",
  SELECT_KEY_LEVEL      = "Nível de chave",
  SELECT_DUNGEONS       = "Masmorras",
  DUNGEONS_MODE_MANUAL  = "Manual",
  DUNGEONS_MODE_AUTO    = "Auto (KrononAlts)",
  DUNGEONS_AUTO_HINT    = "Escolhe as masmorras com o melhor loot pro seu personagem atual.",

  ROLE_TANK             = "Tanque",
  ROLE_HEALER           = "Curador",
  ROLE_DAMAGER          = "DPS",
  CROSSFACTION          = "Cross-facção",
  AUTO_ACCEPT           = "Auto-aceitar (meu grupo)",

  RESULT_GROUP_OF_FMT   = "Grupo %d de %d",
  RESULT_NO_GROUPS      = "Nenhum grupo compatível. Tente Atualizar ou inclua mais masmorras.",
  RESULT_SEARCHING      = "Procurando grupos…",
  RESULT_LEADER         = "Líder",
  RESULT_LEADER_RATING  = "Rating",
  RESULT_AGE_FMT        = "Criado há %s",
  RESULT_SLOTS_NEED     = "Precisa de",
  RESULT_FULL           = "Cheio",
  RESULT_DELISTED       = "Removido",

  APP_PENDING           = "Inscrição pendente…",
  APP_ACCEPTED          = "Aceito!",
  APP_DECLINED          = "Recusado",
  APP_INVITED           = "Convidado!",
  APP_FAILED            = "Inscrição falhou",

  ETA_LABEL             = "Espera est.",
  ETA_FAST              = "< 1 min",
  ETA_MEDIUM            = "1-5 min",
  ETA_SLOW              = "5+ min",
  ETA_UNKNOWN           = "pode demorar",
  ETA_ESTIMATE_NOTE     = "estimativa do addon, não da Blizzard",

  PREVIEW_DROPS         = "Drops",
  PREVIEW_OTHER_DROPS   = "Outros drops",
  PREVIEW_ENDOFRUN_FMT  = "Fim da run: %d (%s %s)",
  PREVIEW_VAULT_FMT     = "Cofre: %d (%s %s)",
  PREVIEW_CREST_FMT     = "Brasão: %dx %s",
  PREVIEW_LOADING       = "Carregando drops…",
  PREVIEW_NO_DATA       = "Sem dados de drop pra esta masmorra ainda.",
  PREVIEW_CREST_DOUBT   = "(a confirmar in-game)",

  CREST_CHAMPION        = "Campeão",
  CREST_HERO            = "Herói",
  CREST_MYTH            = "Mítico",

  SOLO_TITLE            = "Criar meu próprio grupo",
  SOLO_HINT             = "Anuncia um grupo pra masmorra selecionada. Um clique = um anúncio.",

  CONFIG_TITLE          = "Configurações",
  CONFIG_SAVE           = "Pronto",

  MSG_NEED_HARDWARE     = "Esta ação precisa ser iniciada por um clique real do mouse (restrição da Blizzard).",
  MSG_BLOCKED           = "Ação bloqueada pelo jogo — clique direto no botão.",
  MSG_NO_M_PLUS         = "Atividades de Mítica+ ainda não encontradas. Abra o localizador de grupos uma vez e tente de novo.",
  MSG_KA_MISSING        = "KrononAlts não detectado — usando todas as masmorras.",
  MSG_EJ_BUSY           = "Os dados de drop ainda estão carregando — tente daqui a pouco.",

  TOOLTIP_MAGNIFIER     = "Explorar grupos desta liga",
  MINIMAP_TOOLTIP       = "Clique pra abrir  ·  arraste pra mover",
  SLASH_HINT            = "/klfg — abre  ·  /klfg config — configurações",
}

local ES = {
  TAB_LEAGUES           = "Ligas",
  TAB_SEARCH            = "Buscar",
  TAB_PREVIEW           = "Botín",
  TAB_CONFIG            = "Ajustes",

  LEAGUE_CHAMPION       = "Campeón",
  LEAGUE_HERO           = "Héroe",
  LEAGUE_MYTH           = "Mítico",
  LEAGUE_CHAMPION_DESC  = "Botín de la vía Campeón",
  LEAGUE_HERO_DESC      = "Botín de la vía Héroe",
  LEAGUE_MYTH_DESC      = "Cámara de la vía Mítico",
  LEAGUE_RANGE_FMT      = "ilvl %d-%d   ·   +%d-%d",

  BTN_SEARCH            = "Buscar",
  BTN_REFRESH           = "Actualizar",
  BTN_APPLY             = "Inscribirse",
  BTN_SKIP              = "Saltar",
  BTN_CANCEL_APP        = "Cancelar inscripción",
  BTN_CREATE_GROUP      = "Crear mi grupo",
  BTN_UPDATE_LISTING    = "Actualizar anuncio",
  BTN_REMOVE_LISTING    = "Quitar anuncio",
  BTN_OPEN_PREVIEW      = "Botín",
  BTN_BACK              = "Volver",

  MAGNIFIER_TITLE       = "Explorar grupos",
  BREADCRUMB_LEAGUE     = "Liga",
  BREADCRUMB_KEY        = "Llave",
  BREADCRUMB_DUNGEON    = "Mazmorras",
  KEY_LEVEL_FMT         = "+%d",
  SELECT_KEY_LEVEL      = "Nivel de llave",
  SELECT_DUNGEONS       = "Mazmorras",
  DUNGEONS_MODE_MANUAL  = "Manual",
  DUNGEONS_MODE_AUTO    = "Auto (KrononAlts)",
  DUNGEONS_AUTO_HINT    = "Elige las mazmorras con el mejor botín para tu personaje actual.",

  ROLE_TANK             = "Tanque",
  ROLE_HEALER           = "Sanador",
  ROLE_DAMAGER          = "DPS",
  CROSSFACTION          = "Entre facciones",
  AUTO_ACCEPT           = "Auto-aceptar (mi grupo)",

  RESULT_GROUP_OF_FMT   = "Grupo %d de %d",
  RESULT_NO_GROUPS      = "Ningún grupo compatible. Prueba Actualizar o incluye más mazmorras.",
  RESULT_SEARCHING      = "Buscando grupos…",
  RESULT_LEADER         = "Líder",
  RESULT_LEADER_RATING  = "Puntuación",
  RESULT_AGE_FMT        = "Creado hace %s",
  RESULT_SLOTS_NEED     = "Necesita",
  RESULT_FULL           = "Lleno",
  RESULT_DELISTED       = "Retirado",

  APP_PENDING           = "Inscripción pendiente…",
  APP_ACCEPTED          = "¡Aceptado!",
  APP_DECLINED          = "Rechazado",
  APP_INVITED           = "¡Invitado!",
  APP_FAILED            = "Inscripción fallida",

  ETA_LABEL             = "Espera est.",
  ETA_FAST              = "< 1 min",
  ETA_MEDIUM            = "1-5 min",
  ETA_SLOW              = "5+ min",
  ETA_UNKNOWN           = "puede tardar",
  ETA_ESTIMATE_NOTE     = "estimación del addon, no de Blizzard",

  PREVIEW_DROPS         = "Botín",
  PREVIEW_OTHER_DROPS   = "Otro botín",
  PREVIEW_ENDOFRUN_FMT  = "Fin de run: %d (%s %s)",
  PREVIEW_VAULT_FMT     = "Cámara: %d (%s %s)",
  PREVIEW_CREST_FMT     = "Blasón: %dx %s",
  PREVIEW_LOADING       = "Cargando botín…",
  PREVIEW_NO_DATA       = "Aún no hay datos de botín para esta mazmorra.",
  PREVIEW_CREST_DOUBT   = "(a confirmar en el juego)",

  CREST_CHAMPION        = "Campeón",
  CREST_HERO            = "Héroe",
  CREST_MYTH            = "Mítico",

  SOLO_TITLE            = "Crear mi propio grupo",
  SOLO_HINT             = "Anuncia un grupo para la mazmorra seleccionada. Un clic = un anuncio.",

  CONFIG_TITLE          = "Ajustes",
  CONFIG_SAVE           = "Listo",

  MSG_NEED_HARDWARE     = "Esta acción debe iniciarse con un clic real del ratón (restricción de Blizzard).",
  MSG_BLOCKED           = "Acción bloqueada por el juego — haz clic directamente en el botón.",
  MSG_NO_M_PLUS         = "Aún no se encontraron actividades de Mítica+. Abre el buscador de grupos una vez y reintenta.",
  MSG_KA_MISSING        = "KrononAlts no detectado — usando todas las mazmorras.",
  MSG_EJ_BUSY           = "Los datos de botín aún se están cargando — inténtalo en un momento.",

  TOOLTIP_MAGNIFIER     = "Explorar grupos de esta liga",
  MINIMAP_TOOLTIP       = "Clic para abrir  ·  arrastra para mover",
  SLASH_HINT            = "/klfg — abre  ·  /klfg config — ajustes",
}

-- Tenta o KrononLib (i18n) se já estiver carregado e expuser NewLocale; senão,
-- merge manual inline. Tudo defensivo (a lib pode existir sem essa API).
local function BuildLocale()
  local lib
  if LibStub then
    local ok, l = pcall(LibStub, "KrononLib-1.0", true)
    if ok then lib = l end
  end
  if lib and type(lib.NewLocale) == "function" then
    local ok, loc = pcall(function() return lib:NewLocale(EN, { ptBR = PT, esES = ES }) end)
    if ok and type(loc) == "table" then return loc end
  end
  -- Fallback manual (idêntico ao padrão do KrononAlts)
  local L = {}
  for k, v in pairs(EN) do L[k] = v end
  local loc = GetLocale and GetLocale() or "enUS"
  if loc == "esMX" then loc = "esES" end
  local ov = (loc == "ptBR" and PT) or (loc == "esES" and ES) or nil
  if ov then for k, v in pairs(ov) do L[k] = v end end
  setmetatable(L, { __index = function(_, k) return k end })
  return L
end

local L = BuildLocale()

-- ---------------------------------------------------------------------------
-- Namespace público + EventBus interno
-- ---------------------------------------------------------------------------
KrononLFG = KrononLFG or {}
local KLFG = KrononLFG
KLFG.L = L
KLFG.PREFIX = KLFG_PREFIX

local function NewEventBus()
  local cbs = {}
  return {
    Register = function(_, fn) if type(fn) == "function" then cbs[#cbs + 1] = fn end end,
    Fire = function(_, ...) for i = 1, #cbs do pcall(cbs[i], ...) end end,
  }
end
KLFG.bus = NewEventBus()

-- ---------------------------------------------------------------------------
-- Bridge defensiva para o KrononAlts. NUNCA obrigatório: o addon é standalone.
-- Só devolve a tabela global se ela existir e for do tipo certo (pcall de tudo).
-- ---------------------------------------------------------------------------
local function GetKA()
  local ka = _G.KrononAlts
  if type(ka) == "table" then return ka end
  return nil
end
KLFG.GetKA = GetKA

-- Lê uma tabela de dados do KrononAlts se presente; senão usa o fallback local.
local function KAData(key, fallback)
  local ka = GetKA()
  if ka and type(ka[key]) == "table" then return ka[key] end
  return fallback
end

-- ---------------------------------------------------------------------------
-- Tabela de recompensas de Mítica+ — Midnight Season 1 (fallback local; reusa
-- KA.KEY_REWARDS quando o KrononAlts estiver instalado). Espelha Core.lua do
-- KrononAlts. EDITE a cada season.
--   endT/vaultT/crestT: "C" Campeão | "H" Herói | "M" Mítico
-- ---------------------------------------------------------------------------
local KEY_REWARDS_LOCAL = {
  { key = 2,  endI = 250, endT = "C", endR = "2/6", vaultI = 259, vaultT = "H", vaultR = "1/6", crest = 12, crestT = "C" },
  { key = 3,  endI = 250, endT = "C", endR = "2/6", vaultI = 259, vaultT = "H", vaultR = "1/6", crest = 14, crestT = "C" },
  { key = 4,  endI = 253, endT = "C", endR = "3/6", vaultI = 263, vaultT = "H", vaultR = "2/6", crest = 10, crestT = "H" },
  { key = 5,  endI = 256, endT = "C", endR = "4/6", vaultI = 263, vaultT = "H", vaultR = "2/6", crest = 12, crestT = "H" },
  { key = 6,  endI = 259, endT = "H", endR = "1/6", vaultI = 266, vaultT = "H", vaultR = "3/6", crest = 14, crestT = "H" },
  { key = 7,  endI = 259, endT = "H", endR = "1/6", vaultI = 269, vaultT = "H", vaultR = "4/6", crest = 16, crestT = "H" },
  { key = 8,  endI = 263, endT = "H", endR = "2/6", vaultI = 269, vaultT = "H", vaultR = "4/6", crest = 18, crestT = "H" },
  { key = 9,  endI = 263, endT = "H", endR = "2/6", vaultI = 269, vaultT = "H", vaultR = "4/6", crest = 10, crestT = "M" },
  { key = 10, endI = 266, endT = "H", endR = "3/6", vaultI = 272, vaultT = "M", vaultR = "1/6", crest = 12, crestT = "M" },
}
function KLFG.KeyRewards() return KAData("KEY_REWARDS", KEY_REWARDS_LOCAL) end

-- Linha da KEY_REWARDS pra um nível de chave (clamp 2..10). nil = sem dado.
function KLFG.RewardForKey(level)
  local t = KLFG.KeyRewards()
  if type(t) ~= "table" then return nil end
  level = tonumber(level) or 2
  if level < 2 then level = 2 end
  for _, row in ipairs(t) do
    if row.key == level then return row end
  end
  -- +10+ usa a última linha (teto da tabela)
  return t[#t]
end

-- Mapa bonusId -> trilha/ilvl (fallback; reusa KA.UPGRADE_BONUS quando presente).
local UPGRADE_BONUS_LOCAL = {
  [12785] = { code = "C", rank = 1, maxRank = 6, ilvl = 246 },
  [12786] = { code = "C", rank = 2, maxRank = 6, ilvl = 250 },
  [12787] = { code = "C", rank = 3, maxRank = 6, ilvl = 253 },
  [12788] = { code = "C", rank = 4, maxRank = 6, ilvl = 256 },
  [12789] = { code = "C", rank = 5, maxRank = 6, ilvl = 259 },
  [12790] = { code = "C", rank = 6, maxRank = 6, ilvl = 263 },
  [12793] = { code = "H", rank = 1, maxRank = 6, ilvl = 259 },
  [12794] = { code = "H", rank = 2, maxRank = 6, ilvl = 263 },
  [12795] = { code = "H", rank = 3, maxRank = 6, ilvl = 266 },
  [12796] = { code = "H", rank = 4, maxRank = 6, ilvl = 269 },
  [12797] = { code = "H", rank = 5, maxRank = 6, ilvl = 272 },
  [12798] = { code = "H", rank = 6, maxRank = 6, ilvl = 276 },
  [12801] = { code = "M", rank = 1, maxRank = 6, ilvl = 272 },
  [12802] = { code = "M", rank = 2, maxRank = 6, ilvl = 276 },
  [12803] = { code = "M", rank = 3, maxRank = 6, ilvl = 279 },
  [12804] = { code = "M", rank = 4, maxRank = 6, ilvl = 282 },
  [12805] = { code = "M", rank = 5, maxRank = 6, ilvl = 285 },
  [12806] = { code = "M", rank = 6, maxRank = 6, ilvl = 289 },
}
function KLFG.UpgradeBonus() return KAData("UPGRADE_BONUS", UPGRADE_BONUS_LOCAL) end

-- Banner de fundo por dungeon (challengeModeId -> fileID). Mesmos bgTexture do
-- KeystoneLoot (data/dungeons.lua, Season 16 / Midnight S1). Reusa KA.DUNGEON_BG.
local DUNGEON_BG_LOCAL = {
  [161] = 1041999,
  [239] = 1718213,
  [402] = 4742929,
  [556] = 608210,
  [557] = 7464937,
  [558] = 7467174,
  [559] = 7570501,
  [560] = 7478529,
}
function KLFG.DungeonBGTable() return KAData("DUNGEON_BG", DUNGEON_BG_LOCAL) end

-- Masmorras da season (Midnight S1): só challengeModeId + bg. O NOME é resolvido em
-- runtime via C_ChallengeMode.GetMapUIInfo (localizado) — nunca hardcodado.
KLFG.DUNGEON_DATA = {
  { cm = 161 }, { cm = 239 }, { cm = 402 }, { cm = 556 },
  { cm = 557 }, { cm = 558 }, { cm = 559 }, { cm = 560 },
}

-- ⚠️ CM_TO_EJ (challengeModeId -> journalInstanceID): NÃO há API direta e o
-- mapeamento É POR SEASON. Deixamos VAZIO de propósito: o Loot.lua resolve em
-- runtime casando o nome da masmorra (GetMapUIInfo) com as instâncias do
-- Encounter Journal (EJ_GetInstanceByIndex). Se algum dia o match por nome
-- falhar, PREENCHA aqui o journalInstanceID validado in-game
-- (C_ChallengeMode.GetMapTable + EJ_GetInstanceInfo). O instanceId "de mundo" do
-- KeystoneLoot (1209,1753,...) NÃO é journalInstanceID — não usar como atalho.
KLFG.CM_TO_EJ = {
  -- [161] = ?,  -- TODO: validar in-game
}

-- Ligas (cards da tela inicial). Faixa de chave derivada do TIER de drop do
-- END-OF-RUN da KEY_REWARDS: Campeão +2..+5 (endT=C) · Herói +6..+9 (endT=H) ·
-- Mítico +10+ (vault Myth). accent = cor do tier (coerente com o KrononAlts).
-- NOTA: o brasão NÃO é fixo por liga — varia com o nível de chave dentro da faixa
-- (ex.: Campeão +2..+3 dá brasão C, +4..+5 dá H). Por isso ele é DERIVADO em
-- runtime de RewardForKey(keyLevel).crestT (ver KLFG.LeagueCrestTier), não guardado aqui.
KLFG.LEAGUES = {
  { id = "champion", titleKey = "LEAGUE_CHAMPION", descKey = "LEAGUE_CHAMPION_DESC",
    art = "Interface\\AddOns\\KrononLFG\\Media\\league_champion.tga",
    accent = { 0.20, 0.82, 0.48 }, keyLo = 2, keyHi = 5 },
  { id = "hero", titleKey = "LEAGUE_HERO", descKey = "LEAGUE_HERO_DESC",
    art = "Interface\\AddOns\\KrononLFG\\Media\\league_hero.tga",
    accent = { 0.20, 0.55, 1.00 }, keyLo = 6, keyHi = 9 },
  { id = "myth", titleKey = "LEAGUE_MYTH", descKey = "LEAGUE_MYTH_DESC",
    art = "Interface\\AddOns\\KrononLFG\\Media\\league_myth.tga",
    accent = { 1.00, 0.65, 0.10 }, keyLo = 10, keyHi = 10 },
}

-- Faixa de ilvl (end-of-run) de uma liga, derivada da KEY_REWARDS. Retorna lo,hi.
function KLFG.LeagueIlvlRange(league)
  local lo, hi
  for lvl = league.keyLo, league.keyHi do
    local r = KLFG.RewardForKey(lvl)
    if r and r.endI then
      if not lo or r.endI < lo then lo = r.endI end
      if not hi or r.endI > hi then hi = r.endI end
    end
  end
  return lo or 0, hi or 0
end

-- Nível de chave REPRESENTATIVO de uma liga: o nível atual selecionado, preso
-- (clamp) à faixa da liga. Para a liga selecionada, é o nível atual; para as
-- outras, o ponto mais próximo dentro da faixa. Base do brasão DERIVADO — o
-- brasão sai de RewardForKey(este nível).crestT, NUNCA de um tier fixo por liga.
function KLFG.LeagueRepKey(league)
  local lvl = KLFG.GetKeyLevel()
  if type(lvl) ~= "number" then lvl = league.keyLo end
  if lvl < league.keyLo then lvl = league.keyLo end
  if lvl > league.keyHi then lvl = league.keyHi end
  return lvl
end

-- Nome localizado da tier de brasão (para tooltip/labels).
function KLFG.TierName(code)
  if code == "C" then return L.CREST_CHAMPION end
  if code == "H" then return L.CREST_HERO end
  if code == "M" then return L.CREST_MYTH end
  return "?"
end

-- ---------------------------------------------------------------------------
-- Nome / arte da masmorra em runtime (defensivo). GetMapUIInfo(cm) retorna
-- name, id, timeLimit, texture, backgroundTexture (campos variam por versão).
-- ---------------------------------------------------------------------------
function KLFG.DungeonName(cm)
  if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, cm)
    if ok and type(name) == "string" and name ~= "" then return name end
  end
  return "#" .. tostring(cm)
end

-- Ícone da masmorra (4º retorno de GetMapUIInfo). nil se indisponível.
function KLFG.DungeonIcon(cm)
  if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    local ok, _, _, _, texture = pcall(C_ChallengeMode.GetMapUIInfo, cm)
    if ok and texture then return texture end
  end
  return nil
end

-- Banner de fundo: bgTexture hardcoded (KeystoneLoot) e, em último caso, a
-- texture do GetMapUIInfo. nil = sem banner (a UI usa atlas neutro).
function KLFG.DungeonBG(cm)
  local t = KLFG.DungeonBGTable()
  if type(t) == "table" and t[cm] then return t[cm] end
  return KLFG.DungeonIcon(cm)
end

-- ---------------------------------------------------------------------------
-- SavedVariables (account-wide) — KrononLFGDB
-- ---------------------------------------------------------------------------
local DB
local function InitDB()
  if type(KrononLFGDB) ~= "table" then KrononLFGDB = {} end
  local db = KrononLFGDB
  db.version = 1
  if type(db.pos) ~= "table" then db.pos = nil end
  if type(db.minimap) ~= "table" then db.minimap = { angle = 200, hide = false } end
  if type(db.selectedDungeons) ~= "table" then
    -- por padrão, todas as 8 selecionadas
    db.selectedDungeons = {}
    for _, d in ipairs(KLFG.DUNGEON_DATA) do db.selectedDungeons[d.cm] = true end
  end
  if db.dungeonMode ~= "manual" and db.dungeonMode ~= "auto" then db.dungeonMode = "manual" end
  if type(db.role) ~= "table" then db.role = { tank = false, healer = false, damager = true } end
  if type(db.keyLevel) ~= "number" then db.keyLevel = 2 end
  if db.crossFaction == nil then db.crossFaction = true end
  if db.autoAccept == nil then db.autoAccept = false end
  if type(db.league) ~= "string" then db.league = "champion" end
  DB = db
  KLFG.DB = db
end

function KLFG.GetDB() return DB end

-- ---------------------------------------------------------------------------
-- Config: getters/setters persistidos (usados por UI/LFG)
-- ---------------------------------------------------------------------------
function KLFG.GetKeyLevel() return (DB and DB.keyLevel) or 2 end
function KLFG.SetKeyLevel(v)
  v = tonumber(v) or 2
  if v < 2 then v = 2 end
  if v > 30 then v = 30 end
  if DB then DB.keyLevel = v end
  KLFG.bus:Fire("config")
end

function KLFG.GetLeague() return (DB and DB.league) or "champion" end
function KLFG.SetLeague(id)
  if type(id) ~= "string" then return end
  if DB then DB.league = id end
  -- ao trocar de liga, alinha o nível de chave ao piso da faixa
  for _, lg in ipairs(KLFG.LEAGUES) do
    if lg.id == id then
      local cur = KLFG.GetKeyLevel()
      if cur < lg.keyLo or cur > lg.keyHi then KLFG.SetKeyLevel(lg.keyLo) end
      break
    end
  end
  KLFG.bus:Fire("config")
end
function KLFG.GetLeagueById(id)
  for _, lg in ipairs(KLFG.LEAGUES) do if lg.id == id then return lg end end
  return KLFG.LEAGUES[1]
end

function KLFG.GetDungeonMode() return (DB and DB.dungeonMode) or "manual" end
function KLFG.SetDungeonMode(mode)
  if mode ~= "manual" and mode ~= "auto" then return end
  if DB then DB.dungeonMode = mode end
  KLFG.bus:Fire("config")
end

function KLFG.GetCrossFaction() return DB and DB.crossFaction ~= false end
function KLFG.SetCrossFaction(on) if DB then DB.crossFaction = on and true or false end; KLFG.bus:Fire("config") end
function KLFG.GetAutoAccept() return DB and DB.autoAccept == true end
function KLFG.SetAutoAccept(on) if DB then DB.autoAccept = on and true or false end; KLFG.bus:Fire("config") end

-- Papel marcado pelo usuário (vira tankOK/healerOK/damageOK na inscrição).
-- Garante ao menos um papel (nunca inscrever "sem papel").
function KLFG.GetRole()
  local r = (DB and DB.role) or {}
  local tank = r.tank == true
  local healer = r.healer == true
  local damager = r.damager == true
  if not (tank or healer or damager) then damager = true end
  return { tank = tank, healer = healer, damager = damager }
end
function KLFG.SetRole(which, on)
  if not DB then return end
  if type(DB.role) ~= "table" then DB.role = {} end
  DB.role[which] = on and true or false
  KLFG.bus:Fire("config")
end

-- Default de papel a partir de C_LFGList.GetRoles() (uma vez, se o usuário nunca
-- mexeu). Chamado pela UI/LFG defensivamente.
function KLFG.SeedRoleFromGame()
  if not DB or DB.roleSeeded then return end
  DB.roleSeeded = true
  if C_LFGList and C_LFGList.GetRoles then
    local ok, t = pcall(C_LFGList.GetRoles)
    if ok and type(t) == "table" then
      local any = (t.tank or t.healer or t.dps)
      if any then
        DB.role = { tank = t.tank == true, healer = t.healer == true, damager = t.dps == true }
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Seleção de masmorras (API pública: GetSelectedDungeons / SetSelectedDungeons)
--   modo manual: lê DB.selectedDungeons (mapa [cm]=true)
--   modo auto:   pergunta ao KrononAlts (fallback = todas as 8)
-- Retorna sempre uma LISTA (array) de challengeModeId.
-- ---------------------------------------------------------------------------
local function AllDungeonCMs()
  local t = {}
  for _, d in ipairs(KLFG.DUNGEON_DATA) do t[#t + 1] = d.cm end
  return t
end

-- Sugestão do KrononAlts pro modo Auto. Defensivo: se o KA não expuser nada útil,
-- devolve todas. (Hook leve: dá pra evoluir pra ler TRACK_NEXT_KEY/roster depois.)
local function AutoDungeonsFromKA()
  local ka = GetKA()
  if not ka then return AllDungeonCMs() end
  -- Se o KrononAlts publicar uma função de sugestão, usamos; senão, todas.
  if type(ka.SuggestDungeons) == "function" then
    local ok, list = pcall(ka.SuggestDungeons)
    if ok and type(list) == "table" and #list > 0 then return list end
  end
  return AllDungeonCMs()
end

function KLFG.GetSelectedDungeons()
  if KLFG.GetDungeonMode() == "auto" then
    return AutoDungeonsFromKA()
  end
  local sel = (DB and DB.selectedDungeons) or {}
  local list = {}
  for _, d in ipairs(KLFG.DUNGEON_DATA) do
    if sel[d.cm] then list[#list + 1] = d.cm end
  end
  if #list == 0 then return AllDungeonCMs() end -- nunca buscar vazio
  return list
end

function KLFG.IsDungeonSelected(cm)
  local sel = (DB and DB.selectedDungeons) or {}
  return sel[cm] == true
end

function KLFG.SetSelectedDungeons(list)
  if not DB then return end
  DB.selectedDungeons = {}
  if type(list) == "table" then
    -- aceita array de cm OU mapa [cm]=true
    if list[1] ~= nil then
      for _, cm in ipairs(list) do DB.selectedDungeons[cm] = true end
    else
      for cm, v in pairs(list) do if v then DB.selectedDungeons[cm] = true end end
    end
  end
  KLFG.bus:Fire("config")
end

function KLFG.ToggleDungeon(cm)
  if not DB then return end
  if type(DB.selectedDungeons) ~= "table" then DB.selectedDungeons = {} end
  if DB.selectedDungeons[cm] then
    DB.selectedDungeons[cm] = nil
  else
    DB.selectedDungeons[cm] = true
  end
  KLFG.bus:Fire("config")
end

-- ---------------------------------------------------------------------------
-- Event frame + slash. Toggle/Open são definidos em UI.lua (precisam do frame).
-- ---------------------------------------------------------------------------
local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("PLAYER_LOGIN")
ef:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then InitDB() end
  elseif event == "PLAYER_LOGIN" then
    InitDB()
    pcall(KLFG.SeedRoleFromGame)
    if KLFG.InitMinimap then pcall(KLFG.InitMinimap) end
    KLFG.bus:Fire("login")
  end
end)

SLASH_KRONONLFG1 = "/klfg"
SLASH_KRONONLFG2 = "/kronlfg"
SlashCmdList["KRONONLFG"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "config" or msg == "settings" or msg == "cfg" then
    if KLFG.OpenConfig then KLFG.OpenConfig() elseif KLFG.Open then KLFG.Open() end
    return
  elseif msg == "help" or msg == "ajuda" or msg == "ayuda" then
    print(KLFG_PREFIX .. L.SLASH_HINT)
    return
  end
  if KLFG.Toggle then KLFG.Toggle() end
end
