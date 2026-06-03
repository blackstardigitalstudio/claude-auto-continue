#!/bin/bash
# =============================================================================
# resume-picker.sh  --  Check-up con lista per l'app Claude (macOS)
# =============================================================================
# Elenca le sessioni Claude (Chat / Cowork / Code) e ti fa scegliere quali
# riprendere (selezione multipla). Poi apre ognuna e preme la ripresa, e infine
# propone "Offrimi un caffe'".
#
# SICUREZZA: clicca SOLO pulsanti di ripresa. Mai nulla che spenda denaro o
# cambi piano.
#
# REQUISITO: concedi l'accesso "Accessibilita'" al Terminale:
#   Impostazioni di Sistema > Privacy e Sicurezza > Accessibilita'.
#
# NOTA: scritto su Windows. DA VALIDARE SUL MAC: la struttura UI dell'app puo'
# richiedere piccoli aggiustamenti (nomi pulsanti / tempi).
#
# Made in Italy.
# =============================================================================

osascript <<'APPLESCRIPT'
on lc(s)
	try
		return do shell script "printf %s " & quoted form of (s as text) & " | tr 'A-Z' 'a-z'"
	on error
		return s as text
	end try
end lc

set groupTabs to {"Chat", "Cowork", "Code"}
set stateWords to {"In esecuzione", "Inattivo", "In pausa", "In coda", "Pronto", "Completato", "Annullato", "Errore"}
set safeResume to {"continua a lavorare", "continua il lavoro", "riprova", "riprendi"}
set neverClick to {"acquist", "passa a max", "aggiorna il tuo piano", "upgrade", "paga", "piano"}

tell application "System Events"
	if not (exists process "Claude") then
		display notification "L'app desktop Claude non risulta aperta." with title "Claude non trovato"
		return
	end if
	tell process "Claude"
		-- 1) RACCOLTA: per ogni scheda, leggi le voci-sessione
		set displayList to {}
		set seenKeys to {}
		repeat with gt in groupTabs
			try
				click (first button of window 1 whose name is (gt as text))
			end try
			delay 1.2
			try
				set els to entire contents of window 1
				repeat with e in els
					try
						if role of e is "AXButton" then
							set nm to ""
							try
								set nm to (name of e) as text
							end try
							if nm is not "" and nm does not start with "Altre opzioni" then
								repeat with sw in stateWords
									set pref to ((sw as text) & " ")
									if nm starts with pref then
										set ttl to text ((length of pref) + 1) thru -1 of nm
										set k to ((gt as text) & "||" & ttl)
										if seenKeys does not contain k then
											set end of seenKeys to k
											set end of displayList to ("[" & (gt as text) & "] " & ttl & "  (" & (sw as text) & ")")
										end if
										exit repeat
									end if
								end repeat
							end if
						end if
					end try
				end repeat
			end try
		end repeat
	end tell
end tell

if (count of displayList) is 0 then
	display notification "Nessuna sessione trovata in Chat/Cowork/Code." with title "Claude"
	return
end if

-- 2) SCELTA
set chosen to choose from list displayList with title "Riprendi il lavoro" with prompt "Scegli quali conversazioni far ripartire:" with multiple selections allowed
if chosen is false then return

-- 3) RIPRESA delle selezionate
set resumedCount to 0
tell application "System Events"
	tell process "Claude"
		repeat with ch in chosen
			set chs to ch as text
			try
				set grp to text 2 thru ((offset of "]" in chs) - 1) of chs
				set afterBr to text ((offset of "]" in chs) + 2) thru -1 of chs
				set ttl to afterBr
				set p to offset of "  (" in afterBr
				if p > 0 then set ttl to text 1 thru (p - 1) of afterBr
			on error
				set grp to ""
				set ttl to chs
			end try
			-- apri la scheda del gruppo
			try
				click (first button of window 1 whose name is grp)
			end try
			delay 0.9
			-- apri la sessione (pulsante che termina con il titolo)
			try
				set els to entire contents of window 1
				repeat with e in els
					try
						if role of e is "AXButton" then
							set nm to (name of e) as text
							if nm ends with ttl and nm does not start with "Altre opzioni" then
								click e
								exit repeat
							end if
						end if
					end try
				end repeat
			end try
			delay 1.5
			-- clicca la ripresa sicura
			try
				set els2 to entire contents of window 1
				repeat with e2 in els2
					try
						set r2 to role of e2
						if r2 is "AXButton" or r2 is "AXLink" then
							set nm2 to ""
							try
								set nm2 to (name of e2) as text
							end try
							if nm2 is "" then
								try
									set nm2 to (description of e2) as text
								end try
							end if
							if nm2 is not "" then
								set low2 to my lc(nm2)
								set blocked to false
								repeat with bad in neverClick
									if low2 contains (bad as text) then set blocked to true
								end repeat
								if not blocked then
									repeat with ok in safeResume
										if low2 is (ok as text) then
											click e2
											set resumedCount to resumedCount + 1
											delay 2
											exit repeat
										end if
									end repeat
								end if
							end if
						end if
					end try
				end repeat
			end try
		end repeat
	end tell
end tell

display notification ("Riprese " & resumedCount & " sessione/i.") with title "Claude: ripresa"

-- 4) Offrimi un caffe'
if resumedCount > 0 then
	set flagFile to (POSIX path of (path to home folder)) & ".local/share/claude-ac/.no-coffee"
	set showCoffee to true
	try
		do shell script "test -f " & quoted form of flagFile
		set showCoffee to false
	end try
	if showCoffee then
		try
			set rr to button returned of (display dialog "Se claude-ac ti ha salvato del lavoro, offrimi un caffe': mi aiuti a portare avanti aggiornamenti e migliorie." with title "Grazie!" buttons {"Non chiedermelo piu'", "No grazie", "Offrimi un caffe'"} default button 3)
			if rr is "Offrimi un caffe'" then
				open location "https://www.paypal.me/messylove23"
			else if rr is "Non chiedermelo piu'" then
				do shell script "mkdir -p " & quoted form of ((POSIX path of (path to home folder)) & ".local/share/claude-ac") & " ; touch " & quoted form of flagFile
			end if
		end try
	end if
end if
APPLESCRIPT
