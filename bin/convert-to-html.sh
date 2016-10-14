#!/bin/bash

# Liste des répertoires contentant des docx
DIRS=comptes-rendus

BASE=$(dirname $(dirname $0))
SOURCES=$BASE/sources
HTML=$BASE/html
TXT=$BASE/txt

for dir in $DIRS; do
	mkdir -p $HTML/$dir $TXT/$dir
	rm $HTML/$dir/*.html
	soffice --headless --convert-to html --outdir $HTML/$dir $SOURCES/$dir/*.doc $SOURCES/$dir/*.docx $SOURCES/$dir/*.odt
        soffice --headless --convert-to "txt:Text (encoded):UTF8" --outdir $TXT/$dir $SOURCES/$dir/*.doc $SOURCES/$dir/*.docx $SOURCES/$dir/*.odt
done
