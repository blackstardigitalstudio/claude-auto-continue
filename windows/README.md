# claude-ac — Soluzione per l'APP DESKTOP di Claude (Windows)

> Made in Italy 🇮🇹

## Perché serve

Il wrapper `claude-ac` e lo Stop hook funzionano per la **CLI** di Claude Code da
terminale. Ma se usi l'**app desktop** (Claude / Cowork, installata dal Microsoft
Store), quel meccanismo non entra in gioco: l'app gestisce il limite da sola e,
soprattutto, **lo Stop hook non scatta quando finiscono i token** (la sessione va
in errore, non in "stop").

Qui la soluzione usa l'unica via che funziona davvero sull'app: la **UI Automation
di Windows** (la stessa API dei lettori di schermo). Trova il pulsante reale
"Continua a lavorare" / "Riprova" e lo clicca — per nome, non a coordinate.

**Sicurezza:** clicca SOLO i pulsanti di ripresa. Non tocca MAI nulla che spenda
denaro o cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

---

## 1) Tasto "Continua il lavoro" (consigliato) — lo premi tu

Un'icona sul desktop: quando i crediti tornano, la premi e lei clicca "Continua a
lavorare" al posto tuo.

Crea l'icona:

```powershell
powershell -ExecutionPolicy Bypass -File windows\make-shortcut.ps1
```

Oppure esegui direttamente l'azione (utile per provarla):

```powershell
powershell -ExecutionPolicy Bypass -File windows\resume-now.ps1
```

- Se c'è un limite attivo → clicca il pulsante di ripresa e ti avvisa.
- Se non c'è limite → non fa nulla e te lo dice.

---

## 2) Watcher automatico (opzionale) — lo abiliti tu

Un sorvegliante in background che rileva il limite, aspetta il reset e clicca lui
"Continua a lavorare" appena i crediti tornano, avvisandoti con una notifica.

> ⚠️ Questo registra un'attività pianificata che parte all'accesso a Windows e
> agisce in automatico. È **opt-in**: lo attivi tu, consapevolmente.

```powershell
# attiva (parte al login, gira nascosto, si avvia subito)
powershell -ExecutionPolicy Bypass -File windows\install-watcher.ps1

# disattiva
powershell -ExecutionPolicy Bypass -File windows\install-watcher.ps1 -Uninstall
```

Diagnostica (una scansione e basta, non clicca):

```powershell
powershell -ExecutionPolicy Bypass -File windows\resume-watcher.ps1 -Once
```

Log: `%USERPROFILE%\.cache\claude-ac\resume-watcher.log`

---

## File

| File | Cosa fa |
|------|---------|
| `resume-now.ps1` | Azione one-shot: clicca il pulsante di ripresa (il "tasto"). |
| `make-shortcut.ps1` | Crea l'icona "Continua il lavoro - Claude" sul desktop. |
| `resume-watcher.ps1` | Sorvegliante: rileva limite → attende reset → clicca. |
| `install-watcher.ps1` | Registra/rimuove il watcher come attività pianificata. |

## Requisiti

- App desktop **Claude** (Microsoft Store).
- Windows 10/11 con PowerShell (incluso di serie).
