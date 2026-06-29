# KrononLFG

Buscador de grupos prontos de **Mítica+** do ecossistema **Kronon** (World of Warcraft, Interface 120007 — Midnight Season 1).

O foco é o mais próximo possível de **um botão**: você escolhe as masmorras, clica em Procurar, e o KrononLFG ranqueia os grupos disponíveis e apresenta **o melhor de cada vez**. Você confirma a inscrição com **um clique**.

> **Por que não é totalmente automático?** A Blizzard protege `ApplyToGroup`, `CreateListing` e `RemoveListing`: elas só funcionam quando disparadas por um **clique humano**. Não existe inscrição em massa nem auto-loop — qualquer addon que prometa isso falha silenciosamente. O KrononLFG decide *qual* grupo é o melhor; você decide *quando* clicar.

---

**Português**

- **Tela de Ligas** — Campeão / Herói / Mítico, com a faixa de ilvl e de chave de cada uma.
- **Lupa** — nível de chave + as 8 masmorras da season; seleção manual ou automática (via KrononAlts).
- **Resultados 1-a-1** — composição por papel, líder e rating, idade do anúncio e estimativa de espera (heurística).
- **Prévia de drops** — Encounter Journal: o que dropa, ilvl de fim de run/cofre por chave e brasão (*a confirmar* na v0.1.0).
- **Modo solo** — crie seu próprio anúncio com um clique.
- Comando `/klfg` (e `/klfg config`), botão de minimapa.

**English**

- **Leagues screen** — Champion / Hero / Myth, with each one's ilvl and key range.
- **Magnifier** — key level + the season's 8 dungeons; manual or automatic selection (via KrononAlts).
- **One-at-a-time results** — role composition, leader and rating, listing age and a heuristic wait estimate.
- **Drop preview** — Encounter Journal: what drops, end-of-run/vault ilvl per key and crest (*to confirm* in v0.1.0).
- **Solo mode** — list your own group with one click.
- `/klfg` command (and `/klfg config`), minimap button.

**Español**

- **Pantalla de Ligas** — Campeón / Héroe / Mítico, con el rango de ilvl y de llave de cada una.
- **Lupa** — nivel de llave + las 8 mazmorras de la temporada; selección manual o automática (vía KrononAlts).
- **Resultados uno a uno** — composición por rol, líder y puntuación, antigüedad del anuncio y estimación de espera (heurística).
- **Vista previa de botín** — Encounter Journal: qué cae, ilvl de fin de run/cámara por llave y blasón (*a confirmar* en v0.1.0).
- **Modo en solitario** — anuncia tu propio grupo con un clic.
- Comando `/klfg` (y `/klfg config`), botón de minimapa.

---

## Integração com o ecossistema Kronon

O KrononLFG é **standalone**: funciona sozinho. Quando o **KrononAlts** está instalado, ele reusa as tabelas de recompensas/upgrade e pode sugerir automaticamente as masmorras com o melhor loot para o personagem logado. **KrononLib** (i18n) é usado se já estiver carregado.

Namespace público para outros addons do ecossistema:

- `KrononLFG.Toggle()` / `KrononLFG.Open()` / `KrononLFG.OpenConfig()`
- `KrononLFG.GetSelectedDungeons()` / `KrononLFG.SetSelectedDungeons(list)`
- `KrononLFG.Search()` *(deve ser chamada a partir de um clique humano)*
