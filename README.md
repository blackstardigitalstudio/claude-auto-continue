<div align="center">

<img src="https://raw.githubusercontent.com/blackstardigitalstudio/claude-auto-continue/main/banner.png" alt="claude-ac — Auto-Continue per Claude Code" width="100%">

# ☕ claude-ac — Auto-Continue per Claude Code

### Non perdere mai più i tuoi progressi per colpa dei limiti di utilizzo.

La tua sessione di Claude Code si ferma al limite — e **riparte da sola** appena la quota si resetta.
Tu lanci il lavoro una volta. Lui lo finisce mentre tu vivi.

[![Licenza: MIT](https://img.shields.io/badge/Licenza-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/scritto%20in-Bash-1f425f.svg)](#)
[![Piattaforme](https://img.shields.io/badge/piattaforme-macOS%20%7C%20Linux%20%7C%20WSL-blue.svg)](#)
[![Made in Italy](https://img.shields.io/badge/Made%20in-Italy%20%F0%9F%87%AE%F0%9F%87%B9-008C45.svg)](#)
[![PR benvenute](https://img.shields.io/badge/PR-benvenute-brightgreen.svg)](#contribuire)

**🇮🇹 Orgogliosamente progettato in Italia.**

[English](#-english) · [Installazione](#installazione) · [Come funziona](#come-funziona)

</div>

---

## Il problema

Sei nel pieno di un lavoro lungo con Claude Code. Sta andando alla grande.
Poi colpisci il limite di utilizzo: la sessione si ferma, lo slancio muore.
Torni ore dopo, rispieghi tutto il contesto e speri di riprendere da dove eri.

Tempo perso. Concentrazione persa. Lavoro a metà.

## La soluzione

`claude-ac` avvolge Claude Code e registra uno **Stop hook** ufficiale.
Quando una sessione si ferma per il limite di utilizzo, lo rileva, aspetta che
la quota si resetti e **riprende automaticamente la stessa sessione** — esatto,
proprio da dove si era interrotta.

Nessun babysitting. Nessun copia-incolla del contesto. Solo lavoro che si completa.

## Cosa lo rende diverso

- ⚡ **Ripresa automatica al limite** — rileva lo stop da quota e continua al reset.
- 🧠 **Zero supervisione** — lancia un task lungo, vai a vivere, torni a lavoro finito.
- 🔌 **Integrazione nativa** — usa lo Stop hook ufficiale di Claude Code, non un trucco.
- 🛠️ **Installazione in un comando** — configura tutto, hook compreso.
- 🔒 **Sicuro di default** — fa il backup del tuo `settings.json` prima di toccarlo.
- 🪶 **Leggerissimo** — puro Bash. Niente Node, niente Python, niente daemon eterni.

## Usi l'APP DESKTOP di Claude (non il terminale)?

Il wrapper e lo Stop hook valgono per la **CLI** da terminale. Se invece usi
l'**app desktop Claude / Cowork** (Microsoft Store), lo Stop hook non scatta sul
limite di utilizzo. Per quel caso c'è una soluzione dedicata: un tasto **"Continua il lavoro"** sul
desktop (lo premi tu quando i crediti tornano) che clicca al posto tuo e riprende
**tutte** le sessioni bloccate, più un watcher automatico opt-in. Non tocca mai
nulla che spenda denaro.

- 🪟 **Windows** → [`windows/`](windows/README.md) (UI Automation)
- 🍎 **macOS** → [`mac/`](mac/README.md) (Accessibility API)

## Requisiti

- [Claude Code](https://claude.ai/code) (`claude` nel PATH)
- `bash`, `grep`, `sed` (già presenti su macOS/Linux)
- Windows: usalo dentro **WSL** o **Git Bash** (per l'app desktop vedi [`windows/`](windows/README.md))

## Installazione

```bash
git clone https://github.com/blackstardigitalstudio/claude-auto-continue.git
cd claude-auto-continue
./install.sh            # installazione utente (~/.local/bin)
```

Altre opzioni:

```bash
./install.sh --system     # installazione di sistema (/usr/local/bin, richiede sudo)
./install.sh --uninstall  # rimuove tutto
```

L'installer controlla le dipendenze, copia i file e registra lo Stop hook in
`~/.claude/settings.json` (facendo prima un backup di eventuali impostazioni).

## Uso

```bash
claude-ac "costruiscimi una todo app"   # avvia un task con auto-continue
claude-ac --continue                    # riprende l'ultima sessione
claude-ac --ac-help                     # tutte le opzioni
```

Quando Claude Code colpisce il limite, `claude-ac` prende il comando: aspetta il
reset e riprende la sessione automaticamente.

## Come funziona

```
Lanci un task ─▶ Claude Code lavora ─▶ limite raggiunto ─▶ la sessione si ferma
                                                                │
                          parte lo Stop hook (hooks/stop.sh) ◀──┘
                                       │
            rileva il limite ─▶ aspetta il reset ─▶ riprende la sessione ─▶ fatto
```

Claude Code emette un evento **Stop** ogni volta che una sessione termina.
`claude-ac` lo intercetta, distingue uno stop da limite di utilizzo da una
normale conclusione, e rilancia la sessione quando la quota torna disponibile.

## Feedback, domande e consigli

C'è un canale sempre aperto per parlare con noi:

- 💬 **[Discussions](https://github.com/blackstardigitalstudio/claude-auto-continue/discussions)** — domande, idee, consigli (Q&A).
- 🐞 **[Issues](https://github.com/blackstardigitalstudio/claude-auto-continue/issues)** — segnala un bug o chiedi una funzionalità.

Ogni segnalazione e ogni consiglio sono benvenuti: aiutano a migliorare il tool.

## Contribuire

Issue e pull request sono benvenute. Trovi i template in `.github/ISSUE_TEMPLATE/`.

## Licenza

[MIT](LICENSE)

---

<a name="-english"></a>

## 🇬🇧 English

**claude-ac — Auto-Continue for Claude Code.** Never lose progress to usage
limits again. `claude-ac` wraps Claude Code and registers the official **Stop
hook**: when a session stops because of a usage limit, it waits for your quota
to reset and **automatically resumes the same session**, right where it left
off. Pure Bash, macOS / Linux / WSL, MIT licensed.

```bash
git clone https://github.com/blackstardigitalstudio/claude-auto-continue.git
cd claude-auto-continue && ./install.sh
claude-ac "build me a todo app"
```

---

<div align="center">

**Fatto con ❤️ in Italia 🇮🇹** — da [Blackstar Digital Studio](https://blackstardigitalstudio.com)

Se ti ha salvato una sessione, lascia una ⭐ — aiuti altri a trovarlo.

</div>
