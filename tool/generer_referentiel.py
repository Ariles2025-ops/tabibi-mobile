#!/usr/bin/env python3
"""Regenere lib/config/referentiel.dart depuis le site (tabibi-web/src/app/seo/referentiel-seo.ts).

Lit SPECIALITES_SEO et WILAYAS_SEO (slug/code, nom, nomAr) : memes slugs que l'API.
Usage : python3 tool/generer_referentiel.py [chemin/vers/referentiel-seo.ts]
"""
import json
import pathlib
import re
import sys

ICI = pathlib.Path(__file__).resolve().parent.parent
SOURCE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ICI.parent / 'tabibi-web/src/app/seo/referentiel-seo.ts'
CIBLE = ICI / 'lib/config/referentiel.dart'


def tableau(texte, nom):
    m = re.search(r'export const ' + nom + r'\s*:\s*\w+\[\]\s*=\s*(\[.*?\n\]);', texte, re.S)
    if not m:
        sys.exit(f'{nom} introuvable dans {SOURCE}')
    return json.loads(m.group(1))


def dart(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


texte = SOURCE.read_text(encoding='utf-8')
specialites = tableau(texte, 'SPECIALITES_SEO')
wilayas = tableau(texte, 'WILAYAS_SEO')

lignes = [
    "/// Referentiel identique au site (tabibi-web/src/app/seo/referentiel-seo.ts) : memes slugs que l'API.",
    '/// Genere automatiquement par tool/generer_referentiel.py ; ne pas modifier a la main.',
    'library;',
    '',
    'class Specialite {',
    '  const Specialite(this.slug, this.nom, this.nomAr);',
    '  final String slug;',
    '  final String nom;',
    '  final String nomAr;',
    '}',
    '',
    'class Wilaya {',
    '  const Wilaya(this.code, this.nom, this.nomAr);',
    '  final String code;',
    '  final String nom;',
    '  final String nomAr;',
    '}',
    '',
    'const specialites = <Specialite>[',
]
lignes += [f"  Specialite({dart(s['slug'])}, {dart(s['nom'])}, {dart(s['nomAr'])})," for s in specialites]
lignes += ['];', '', 'const wilayas = <Wilaya>[']
lignes += [f"  Wilaya({dart(w['code'])}, {dart(w['nom'])}, {dart(w['nomAr'])})," for w in wilayas]
lignes += ['];', '']
CIBLE.write_text('\n'.join(lignes), encoding='utf-8')
print(f'{len(specialites)} specialites, {len(wilayas)} wilayas -> {CIBLE.relative_to(ICI)}')
