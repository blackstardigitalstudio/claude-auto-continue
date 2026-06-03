# claude-ac — Soluzione per l'APP DESKTOP di Claude (macOS)

> Made in Italy 🇮🇹
> ⚠️ **Stato: da validare sul Mac.** Questi script sono scritti e revisionati ma
> sviluppati su Windows: la prima volta vanno provati sul Mac e, se serve,
> rifiniti. La logica e la sicurezza sono identiche alla versione Windows.

## Perché serve

Come su Windows: l'app desktop (Claude / Cowork) non passa dal wrapper da
terminale e lo Stop hook non scatta sul limite di utilizzo. Su macOS pilotiamo
l'app tramite l'**Accessibility API** (AppleScript / `osascript`), cliccando il
pulsante reale "Continua a lavorare" / "Riprova".

**Sicurezza:** clicca SOLO i pulsanti di ripresa. Non tocca MAI nulla che spenda
denaro o cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).

## Permesso necessario (una volta sola)

Concedi l'accesso **Accessibilità** all'app che lancia lo script (Terminale o il
tasto stesso):

> Impostazioni di Sistema → Privacy e Sicurezza → **Accessibilità** → abilita
> *Terminale* (o l'app del tasto).

Senza questo permesso macOS blocca i clic automatici.

## Tasto "Continua il lavoro" — lo premi tu

```bash
bash mac/make-shortcut-mac.sh
```

Crea sul Desktop **"Continua il lavoro - Claude.command"**: quando i crediti
tornano, doppio clic e Claude riprende. Per rimuoverlo:

```bash
bash mac/make-shortcut-mac.sh --uninstall
```

Per provare l'azione direttamente:

```bash
bash mac/resume-now.sh
```

- Se c'è un pulsante di ripresa → lo clicca e ti avvisa con una notifica.
- Se non c'è → non fa nulla e te lo dice.

## File

| File | Cosa fa |
|------|---------|
| `resume-now.sh` | Azione: clicca i pulsanti sicuri di ripresa (il "tasto"). |
| `make-shortcut-mac.sh` | Crea il tasto `.command` sul Desktop. |

## Note

- Multi-sessione: la versione Windows cicla tutte le sessioni della barra
  laterale. Su Mac la versione attuale clicca i pulsanti di ripresa presenti
  nelle finestre aperte; il ciclo completo delle sessioni va validato/rifinito
  sul Mac.
- Watcher automatico (opt-in) disponibile su richiesta, come su Windows.
