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

## 1) Tasti sul desktop (consigliato) — li premi tu

Crea le icone:

```powershell
powershell -ExecutionPolicy Bypass -File windows\make-shortcut.ps1
```

Ne ottieni due:

- **"Continua il lavoro - Claude"** — riprende **tutte** le sessioni bloccate.
- **"Scegli sessioni - Claude"** — apre un **check-up con lista a spunta**: vedi
  le sessioni, spunti solo quelle che ti interessano (le chat vecchie che non usi
  restano ferme), poi "Riprendi selezionate". C'è anche "Rileva bloccate" che
  spunta da solo quelle davvero ferme per il limite, e "Ricorda la selezione".

  > Nota: il check-up elenca le sessioni mostrate nella **vista attiva** (Cowork
  > o Code) della barra laterale. Per includere le sessioni Code, passa prima
  > alla scheda Code e poi apri il check-up.

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

## Preferisci un .exe?

Puoi usare il tool in due modi (a tua scelta):

- **Script + icone** (consigliato): leggero, trasparente, facile da aggiornare.
- **.exe**: genera due eseguibili con l'icona incorporata (`Continua il lavoro.exe`,
  `Scegli sessioni.exe`) che avviano gli script affiancati:

  ```powershell
  powershell -ExecutionPolicy Bypass -File windows\make-icon.ps1   # crea l'icona
  powershell -ExecutionPolicy Bypass -File windows\build-exe.ps1    # crea i due .exe
  ```

  Nota: alla prima apertura Windows SmartScreen puo' mostrare un avviso perche'
  l'eseguibile non e' firmato. E' un launcher trasparente (apre lo script
  PowerShell affiancato): clicca "Ulteriori informazioni" > "Esegui comunque".

## File

| File | Cosa fa |
|------|---------|
| `resume-now.ps1` | Riprende tutte le sessioni bloccate (il "tasto"). `-Single` per la sola sessione aperta. |
| `resume-picker.ps1` | Check-up: lista a spunta delle sessioni, riprendi solo le selezionate. |
| `make-shortcut.ps1` | Crea le due icone sul desktop ("Continua il lavoro" e "Scegli sessioni"). |
| `resume-watcher.ps1` | Sorvegliante: rileva limite → attende reset → clicca. |
| `install-watcher.ps1` | Registra/rimuove il watcher come attività pianificata. |

## Requisiti

- App desktop **Claude** (Microsoft Store).
- Windows 10/11 con PowerShell (incluso di serie).
