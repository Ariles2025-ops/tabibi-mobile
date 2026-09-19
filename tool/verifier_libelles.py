#!/usr/bin/env python3
"""Controle d'internationalisation : aucun libelle francais ne doit rester ecrit en dur
dans les ecrans.

Toutes les chaines litterales de `lib/pages` (et de `lib/main.dart`, qui porte l'accueil)
sont relues hors commentaires ; celles qui portent un caractere accentue francais ou un
guillemet francais sont signalees : un libelle affiche passe par `t(context, cle)` et vit
dans `lib/i18n/traductions.dart`, jamais dans la page.

Usage : python3 tool/verifier_libelles.py [racine]
"""
import os
import sys

RACINE = sys.argv[1] if len(sys.argv) > 1 else '.'

# Fichiers relus : les ecrans (les dictionnaires, eux, contiennent evidemment des accents).
CIBLES = [os.path.join('lib', 'pages'), os.path.join('lib', 'main.dart')]

ACCENTS = set('aaaceeeeiioouuuAAACEEEEIIOOUUUàâäçéèêë'
              'îïôöùûüÀÂÄÇÉ'
              'ÈÊËÎÏÔÖÙÛÜ«»')
# Seuls les caracteres hors ASCII comptent (les lettres simples ci-dessus sont ignorees).
ACCENTS = {c for c in ACCENTS if ord(c) > 127}


def chaines(source):
    """Chaines litterales d'un fichier Dart, hors commentaires : [(ligne, contenu)]."""
    trouvees = []
    i, n, ligne = 0, len(source), 1
    while i < n:
        c = source[i]
        if c == '\n':
            ligne += 1
            i += 1
            continue
        if source.startswith('//', i):
            fin = source.find('\n', i)
            i = n if fin < 0 else fin
            continue
        if source.startswith('/*', i):
            fin = source.find('*/', i + 2)
            if fin < 0:
                break
            ligne += source.count('\n', i, fin)
            i = fin + 2
            continue
        if c in '"\'':
            triple = source.startswith(c * 3, i)
            fermeture = c * 3 if triple else c
            j = i + (3 if triple else 1)
            debut = j
            while j < n:
                if source[j] == '\\':
                    j += 2
                    continue
                if source.startswith(fermeture, j):
                    break
                if not triple and source[j] == '\n':
                    break
                j += 1
            trouvees.append((ligne, source[debut:j]))
            ligne += source.count('\n', i, j)
            i = j + len(fermeture)
            continue
        i += 1
    return trouvees


def fichiers():
    for cible in CIBLES:
        chemin = os.path.join(RACINE, cible)
        if os.path.isfile(chemin):
            yield chemin
            continue
        for dossier, _, noms in os.walk(chemin):
            for nom in sorted(noms):
                if nom.endswith('.dart'):
                    yield os.path.join(dossier, nom)


def main():
    anomalies = []
    for chemin in fichiers():
        source = open(chemin, encoding='utf-8').read()
        for ligne, texte in chaines(source):
            if any(c in ACCENTS for c in texte):
                anomalies.append(f'{chemin}:{ligne}: libelle francais en dur : {texte[:60]!r}')
    for a in anomalies:
        print(a)
    print('OK : aucun libelle francais en dur dans les ecrans' if not anomalies
          else f'{len(anomalies)} libelle(s) a deplacer dans lib/i18n/traductions.dart')
    return 1 if anomalies else 0


if __name__ == '__main__':
    sys.exit(main())
