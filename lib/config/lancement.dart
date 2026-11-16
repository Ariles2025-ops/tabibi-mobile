/// Memes drapeaux que le site (tabibi-web/src/app/lancement.ts) : une seule plateforme.
///
/// [prelancement] : bandeau « Lancement prochainement » ; la connexion reste possible pour les
/// comptes existants (equipe, examinateurs des stores), comme l'acces equipe du site.
/// [visioActive] : la teleconsultation affiche « Bientôt » tant qu'elle est fermee
/// (cote serveur : TABIBI_TELECONSULTATION_ACTIVE=false).
library;

const bool prelancement = bool.fromEnvironment('TABIBI_PRELANCEMENT', defaultValue: true);
const bool visioActive = bool.fromEnvironment('TABIBI_VISIO_ACTIVE', defaultValue: false);
