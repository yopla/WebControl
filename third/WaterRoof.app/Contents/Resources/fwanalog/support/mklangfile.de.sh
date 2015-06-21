#! /bin/sh

# Shell script to convert an Analog language file to a fwAnalog one.
# Language/Sprache: German/Deutsch
# Usage: mklangfile.de.sh {infile} [> outfile]
# 	infile should be de.lng, not dea.lng
# $Id: mklangfile.de.sh,v 1.4 2002/05/11 19:05:06 bb Exp $

cat $1 \
	| sed 's/Anzahl unterschiedlicher anfragender Hosts/Verschiedene Hosts, deren Pakete blockiert wurden/g' \
	| sed 's/Anzahl unterschiedlicher verlangter Dateien/Verschiedene blockierte Pakete/g' \
	| sed 's/Verzeichnis[ -]Bericht/Bericht über blockierte Pakete/g' \
	| sed 's!Anfrage[ -]Bericht!Port-/ICMP-Typ-Bericht!g' \
	| sed 's!Dateigröße\(n*\)!Paketgröße\1!g' \
	| sed 's!\(verlangten \)*Dateien!Ports/ICMP-Typen!g' \
	| sed 's!\(verlangten \)*Datei!Port/ICMP-Typ!g' \
	| sed 's!Gesamtanzahl der Anfragen!Gesamtanzahl der blockierten Pakete!g' \
	| sed 's!Anfragen!blockierten Paketen!g' \
	| sed 's!Anfrage!blockiertes Paket!g' \
	| sed 's!verlangten Pakete!Ports bzw. ICMP-Typen!g' \
	| sed 's/erster Zugriff/erstes bl. Paket/g' \
	| sed 's/letzter Zugriff/letztes bl. Paket/g' \
	| sed 's/Virtueller[ -]\(Host\|Server\)[ -]Bericht/Netzwerkschnittstellen-Bericht/g' \
	| sed 's/[vV]irtueller \(Host\|Server\)/Netzwerkschnittstelle/g' \
	| sed 's/[vV]irtuellen* Hosts/Netzwerkschnittstellen/g' \
	| sed 's/[vV]irtuellen* Server/Netzwerkschnittstellen/g' \
	| sed 's/Verzeichnisses/blockierten Pakets/g' \
	| sed 's/Verzeichnisse/blockierten Pakete/g' \
	| sed 's/Verzeichnis/blockiertes Paket/g' \
	| sed "s/URL'*/Quellport/g" \
	| sed 's/Browser/MAC-Adresse(n)/g' \
	| sed 's/Server[ -]Statistiken f.*r/Firewall-Statistiken, generiert von/g' \
	| sed 's/Monat mit der stärksten Nutzung:/Monat mit den meisten blockierten Paketen:/g' \
	| sed 's/Woche mit der stärksten Nutzung:/Woche mit den meisten blockierten Paketen:/g' \
	| sed 's/Tag mit der stärksten Nutzung:/Tag mit den meisten blockierten Paketen:/g' \
	| sed 's/Uhrzeit mit der stärksten Nutzung:/Uhrzeit mit den meisten blockierten Paketen:/g' \
	| sed 's/Stunde mit der stärksten Nutzung:/Stunde mit den meisten blockierten Paketen:/g' \
	| sed 's/Viertelstunde mit der stärksten Nutzung:/Viertelstunde mit den meisten blockierten Paketen:/g' \
	| sed 's/5 Minuten mit der stärksten Nutzung:/5 Minuten mit den meisten blockierten Paketen:/g' \
	| sed 's/Host[ -]Bericht/Paket-Quell-Host-Bericht/g' \
	| sed 's/REM Verzeichnis[ -]Bericht/Bericht über blockierte Pakete/g' \
	| sed 's/Verweis[ -]Bericht/Quellport-Bericht/g' \
	| sed 's/verweisenden URL/Quellport/g' \
	| sed 's/Erfolgreich/Blockiert/g' \
	| sed 's/Nichtverwendete.*Logdatei/Nicht verwendete Einträge in der Logdatei (wegen Datum, EXCLUDE usw.)/g' \
	| sed 's/Menge verschickter Daten/Größe aller blockierten Pakete zusammen/g' \
	| sed 's/Durchschnittliche Menge verschickter Daten pro Tag/Durchschnittliche tägliche Größer blockierter Pakete/g' \
	| sed 's/#Anf./#Blocks/g' \
	| sed 's/%Anf./%Blocks/g' \
	| sed 's/verweisenden //g' \
	| sed 's/Blockiert bearbeitete blockierten/Blockierte/g' \
	| sed 's/bearbeitete blockierten/blockierte/g' \
	| sed 's/^Blockierte Pakete\(n*\)/Blockierte Pakete/g' \
	| sed 's/ch blockierte Pakete\(n*\)/ch blockierte Pakete/g' \
	| sed 's/aller blockierten Pakete\(n\)*/aller blockierten Pakete/g' \
	| sed 's/der blockierten Pakete\(n\)*/der blockierten Pakete/g' \
	| sed 's/Benutzers/Log-Präfixes/g' \
	| sed '/WWW-Server/,/Benutzer/s/Benutzer/Log-Präfix/' \
	| sed '/Benutzer/,/Status-Code/s/Benutzer/Log-Präfixe/' \
	| sed 's/Benutzer/Log-Präfix/g' \
	| sed 's/Log-Präfixe[ -]Bericht/Log-Präfix-Bericht/g' \
	| sed 's/blockiertes Paketbericht/Bericht über blockierte Pakete/g' \
	| sed 's/entspricht \([0-9]*\) blockierten Pakete/entspricht \1 blockierten Paketen/g' \
	| sed 's/mindestens \([0-9]*\) blockiertem Paket/mindestens \1 blockierten Paket/g' \
	| sed 's/ Bericht$/-Bericht/g' \
	| sed 's/ Übersicht$/-Übersicht/g' \
	| perl -pwe "s!^## This is a language file for analog!## Converted from $1 on `date` \\n## by mklangfile.de.sh (from the fwanalog distribution)\\n## More info: http://tud.at/programm/fwanalog/\\n##\\n## This is a language file for analog!" 
