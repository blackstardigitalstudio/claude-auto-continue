<div align="center">

<img src="https://raw.githubusercontent.com/blackstardigitalstudio/claude-auto-continue/main/banner.png" alt="claude-ac — Auto-Continue per Claude Code" width="100%">

# ☕ claude-ac — Auto-Continue per Claude (app desktop & CLI)

### Non perdere mai più i tuoi progressi per colpa dei limiti di utilizzo.

Quando finisci i crediti, **claude-ac fa ripartire il lavoro**: con un clic quando ti
torna comodo, oppure **da solo** appena la quota si resetta (se attivi la ripresa
automatica). Funziona con l'**app desktop di Claude** (Windows e macOS) e con la **CLI**.

[![Licenza: MIT](https://img.shields.io/badge/Licenza-MIT-green.svg)](LICENSE)
[![Linguaggi](https://img.shields.io/badge/PowerShell%20%2B%20Bash-1f425f.svg)](#)
[![Piattaforme](https://img.shields.io/badge/piattaforme-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)](#)
[![Made in Italy](https://img.shields.io/badge/Made%20in-Italy%20%F0%9F%87%AE%F0%9F%87%B9-008C45.svg)](#)
[![PR benvenute](https://img.shields.io/badge/PR-benvenute-brightgreen.svg)](#contribuire)

**🇮🇹 Orgogliosamente progettato in Italia.**

[English](#-english) · [Installazione](#installazione) · [Come funziona](#come-funziona)

</div>

---

## Il problema

Sei nel pieno di un lavoro lungo con Claude. Sta andando alla grande.
Poi colpisci il limite di utilizzo: la sessione si ferma, lo slancio muore.
Torni ore dopo e devi rimetterti lì a far ripartire tutto a mano.

Tempo perso. Concentrazione persa. Lavoro a metà.

## La soluzione

Quando colpisci il limite, `claude-ac` riprende il lavoro per te. **Tre modi, scegli il tuo:**

- 🖱️ **Manuale (un clic)** — quando i crediti tornano, premi il tasto **"Continua il
  lavoro"** e le sessioni bloccate ripartono. Oppure usa il check-up **"Scegli
  sessioni"** per riattivare solo quelle che ti interessano.
- 🤖 **Automatico (opt-in)** — attivi la **ripresa automatica** e `claude-ac` fa la
  guardia: aspetta il reset della quota e **riparte da solo**, senza che tu prema niente.
- ⌨️ **Da terminale** — il wrapper `claude-ac` avvolge la CLI di Claude Code, riconosce
  il limite nell'output, aspetta il reset e riprova in automatico.

Nessun copia-incolla del contesto. Solo lavoro che si completa.

## Cosa lo rende diverso

- ⚡ **Ripresa al limite** — con un clic, o automatica appena i crediti tornano.
- 🗂️ **Scegli cosa riprendere** — il check-up elenca le sessioni divise per **Chat /
  Cowork / Code**: riattivi solo le chat giuste, le altre restano ferme.
- 🖥️ **App desktop *e* terminale** — Windows (UI Automation), macOS (Accessibility), CLI (Bash).
- 🔒 **Non spende mai soldi** — clicca solo i pulsanti di ripresa, mai acquisti o upgrade.
- 🛡️ **Niente porte aperte, niente backdoor, niente telemetria** — codice locale e leggibile.
- 🪶 **Leggero** — semplici script (PowerShell / Bash). Nessun daemon eterno, a meno che tu non scelga la modalità automatica.

## Piattaforme

| | Come |
|---|---|
| 🪟 **Windows** (app desktop) | UI Automation → [`windows/`](windows/README.md) |
| 🍎 **macOS** (app desktop) | Accessibility API → [`mac/`](mac/README.md) |
| ⌨️ **CLI** (macOS / Linux / WSL / Git Bash) | wrapper Bash → [`install.sh`](install.sh) |

## Installazione

### App desktop — Windows

```powershell
git clone https://github.com/blackstardigitalstudio/claude-auto-continue.git
cd claude-auto-continue
powershell -ExecutionPolicy Bypass -File windows\make-shortcut.ps1
```

Crea sul Desktop due tasti: **"Continua il lavoro"** (riprende tutto) e **"Scegli
sessioni"** (check-up con lista). Preferisci un `.exe`? Vedi [`windows/`](windows/README.md).
Vuoi la **ripresa automatica** (opt-in)? `powershell -ExecutionPolicy Bypass -File windows\install-watcher.ps1`.

### App desktop — macOS

```bash
git clone https://github.com/blackstardigitalstudio/claude-auto-continue.git
cd claude-auto-continue
bash mac/make-shortcut-mac.sh
```

Crea sul Desktop i due tasti `.command`. La prima volta concedi l'accesso
**Accessibilità** al Terminale (Impostazioni di Sistema → Privacy e Sicurezza →
Accessibilità). Dettagli in [`mac/`](mac/README.md).

### Terminale (CLI)

```bash
git clone https://github.com/blackstardigitalstudio/claude-auto-continue.git
cd claude-auto-continue && ./install.sh
claude-ac "costruiscimi una todo app"
```

## Uso

**App desktop:** quando vedi "Limite di utilizzo raggiunto" e poi i crediti tornano,
lascia aperta l'app Claude e fai doppio clic su **"Continua il lavoro"** (riprende
tutto) oppure su **"Scegli sessioni"** (scegli quali riattivare). In modalità
automatica non devi fare nulla: riparte da solo.

**CLI:**

```bash
claude-ac "scrivi i test per main.py"   # avvia con auto-continue
claude-ac --continue                    # riprende l'ultima sessione
claude-ac --ac-help                     # tutte le opzioni
```

## Come funziona

- **App desktop** — `claude-ac` trova la finestra di Claude e clicca il vero pulsante
  **"Continua a lavorare"** tramite la **UI Automation di Windows** / la **Accessibility
  API di macOS** (la stessa tecnologia dei lettori di schermo). In modalità automatica
  un sorvegliante controlla a intervalli e clicca da solo appena la quota torna.
- **CLI** — il wrapper esegue `claude`, legge l'output, riconosce il messaggio di limite,
  aspetta il reset e rilancia con `--continue`.

> **Nota tecnica (onestà):** quando finiscono i crediti, Claude **non** emette un evento
> "Stop", quindi sull'app desktop la ripresa avviene via UI Automation (non tramite hook).
> È il motivo per cui esistono il tasto e la modalità automatica.

**Sicurezza:** nessun listener, nessuna porta aperta, nessun download di codice, nessuna
telemetria. L'unica connessione a internet è l'apertura della pagina PayPal nel browser,
**solo se** clicchi "Offrimi un caffè".

## ☕ Offrimi un caffè

Se `claude-ac` ti ha salvato del lavoro, puoi sostenere gli aggiornamenti:
**[paypal.me/messylove23](https://www.paypal.me/messylove23)** — oppure il bottone
**Sponsor** in cima al repository. Grazie! 🙏

## Feedback, domande e consigli

C'è un canale sempre aperto:

- 💬 **[Discussions](https://github.com/blackstardigitalstudio/claude-auto-continue/discussions)** — domande, idee, consigli (Q&A).
- 🐞 **[Issues](https://github.com/blackstardigitalstudio/claude-auto-continue/issues)** — segnala un bug o chiedi una funzionalità.

## Contribuire

Issue e pull request sono benvenute. Trovi i template in `.github/ISSUE_TEMPLATE/`.

## Licenza

[MIT](LICENSE)

---

<a name="-english"></a>

## 🇬🇧 English

# claude-ac — Auto-Continue for Claude (desktop app & CLI)

**Never lose progress to usage limits again.** When you hit your limit, `claude-ac`
gets your work going again — with one click when it suits you, or **automatically**
as soon as your quota resets (if you enable auto-resume). Works with the **Claude
desktop app** (Windows & macOS) and with the **CLI**.

### Three ways to use it

- 🖱️ **Manual (one click)** — when credits are back, press the **"Continua il lavoro"**
  (Resume work) button and the blocked sessions restart. Or use the **"Scegli sessioni"**
  (Pick sessions) check-up to resume only the ones you want.
- 🤖 **Automatic (opt-in)** — enable auto-resume and `claude-ac` watches, waits for the
  reset and **resumes by itself**, no clicking needed.
- ⌨️ **Terminal** — the `claude-ac` wrapper wraps the Claude Code CLI, detects the limit
  in the output, waits for the reset and retries with `--continue`.

### How it works

- **Desktop app** — `claude-ac` finds the Claude window and clicks the real
  **"Continua a lavorare"** button through **Windows UI Automation** / the **macOS
  Accessibility API**. In automatic mode a small watcher clicks it for you as soon as the
  quota returns.
- **CLI** — the wrapper runs `claude`, reads the output, recognizes the limit message and
  relaunches at reset.

> **Honest note:** Claude does **not** emit a "Stop" event when you run out of credits,
> so on the desktop app the resume is done via UI Automation (not via a hook). That's why
> the button and the automatic mode exist.

**Safety:** no listeners, no open ports, no code downloads, no telemetry. The only internet
action is opening the PayPal page in your browser — **only if** you click "Buy me a coffee".

### Install (quick)

```bash
# Windows desktop app
powershell -ExecutionPolicy Bypass -File windows\make-shortcut.ps1
# macOS desktop app
bash mac/make-shortcut-mac.sh
# CLI
./install.sh
```

Platforms: Windows / macOS (desktop app) and macOS / Linux / WSL / Git Bash (CLI). MIT licensed.
If it saves you a session, a ⭐ helps others find it — and you can support updates at
[paypal.me/messylove23](https://www.paypal.me/messylove23).

---

<div align="center">

**Fatto con ❤️ in Italia 🇮🇹** — da [Blackstar Digital Studio](https://blackstardigitalstudio.com)

Se ti ha salvato una sessione, lascia una ⭐ — aiuti altri a trovarlo.

</div>
