#!/bin/bash
# =============================================================================
# resume-now.sh  --  Tasto "Continua il lavoro" per l'app Claude (macOS)
# =============================================================================
# Lo lanci TU quando i crediti sono tornati. Trova l'app desktop Claude e
# clicca al posto tuo i pulsanti sicuri di ripresa ("Continua a lavorare" /
# "Riprova"), usando l'Accessibility API di macOS via AppleScript.
#
# SICUREZZA: clicca SOLO pulsanti di ripresa. Non tocca MAI nulla che spenda
# denaro o cambi piano (Acquista crediti, Passa a Max, Aggiorna piano).
#
# REQUISITO: la prima volta devi concedere l'accesso "Accessibilità" al
# programma che lancia lo script (Terminale / l'app del tasto):
#   Impostazioni di Sistema > Privacy e Sicurezza > Accessibilità > abilita.
#
# NOTA: scritto e revisionato ma da VALIDARE sul Mac (sviluppato su Windows).
#
# Made in Italy.
# =============================================================================

osascript <<'APPLESCRIPT'
-- minuscolo via shell (robusto su accenti ASCII)
on lc(s)
	try
		return do shell script "printf %s " & quoted form of (s as text) & " | tr 'A-Z' 'a-z'"
	on error
		return s as text
	end try
end lc

set safeList to {"continua a lavorare", "continua il lavoro", "riprova", "riprendi", "continue working", "continue"}
set neverList to {"acquist", "passa a max", "aggiorna il tuo piano", "upgrade", "paga", "purchase", "buy", "piano"}
set clicked to 0

tell application "System Events"
	if not (exists process "Claude") then
		display notification "L'app desktop Claude non risulta aperta." with title "Claude non trovato"
		return "App Claude non in esecuzione."
	end if
	tell process "Claude"
		repeat with w in windows
			try
				set els to entire contents of w
				repeat with e in els
					set r to ""
					try
						set r to role of e
					end try
					if r is "AXButton" or r is "AXLink" then
						set nm to ""
						try
							set nm to (name of e) as text
						end try
						if nm is "" then
							try
								set nm to (description of e) as text
							end try
						end if
						if nm is not "" then
							set low to my lc(nm)
							set blocked to false
							repeat with bad in neverList
								if low contains (bad as text) then set blocked to true
							end repeat
							if not blocked then
								repeat with ok in safeList
									if low is (ok as text) then
										try
											click e
											set clicked to clicked + 1
											delay 1.5
										end try
										exit repeat
									end if
								end repeat
							end if
						end if
					end if
				end repeat
			end try
		end repeat
	end tell
end tell

if clicked > 0 then
	display notification ("Ho ripreso " & clicked & " sessione/i.") with title "Claude: lavoro ripreso!"
else
	display notification "Nessuna sessione bloccata dal limite ora." with title "Niente da riprendere"
end if
return "Ripreso " & clicked & " sessione/i."
APPLESCRIPT
