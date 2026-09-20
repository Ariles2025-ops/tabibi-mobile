import 'supabase_service.dart';

/// Acces direct a l'annuaire des praticiens via Supabase (RPC SECURITY DEFINER,
/// lisibles par `anon`) : recherche, vitrine, statistiques, fiche.
///
/// Aucune dependance au backend : l'app affiche les 75 000+ praticiens meme
/// sans serveur lance. Les champs de la vue `public_doctors` (anglais) sont
/// traduits vers les cles attendues par l'UI (francais).
class PraticiensSupabase {
  const PraticiensSupabase();

  /// Traduit une ligne `public_doctors` vers les cles utilisees par les ecrans.
  Map<String, dynamic> _map(Map<dynamic, dynamic> v) => {
        'id': v['id'],
        'nomComplet': v['full_name'],
        'specialiteFr': v['specialty_fr'],
        'ville': v['city'],
        'wilayaFr': v['wilaya_fr'],
        'note': v['rating'],
        'nombreAvis': v['review_count'],
        'langues': v['languages'],
        'accepteCarte': v['accepts_card'],
        'accepteChifa': v['accepts_chifa'],
        'accepteEspeces': v['accepts_cash'],
        'teleconsultation': v['telehealth_enabled'],
        'typeEntite': v['entity_type'],
        'bio': v['bio'],
        'photo': v['photo_url'],
        'verifie': v['is_verified'],
        'tarif': v['consultation_fee_dzd'],
        'teleTarif': v['telehealth_fee_dzd'],
      };

  List<Map<String, dynamic>> _mapListe(Object? liste) =>
      ((liste as List?) ?? const [])
          .map((e) => _map(e as Map))
          .toList();

  /// Recherche de praticiens. `chercher_praticiens` exige au moins un critere ;
  /// sans critere on renvoie la vitrine (praticiens mis en avant).
  Future<List<Map<String, dynamic>>> rechercher({
    String? specialite,
    String? wilaya,
    String? q,
    int page = 1,
    int limite = 20,
  }) async {
    final aWilaya = wilaya != null && wilaya.isNotEmpty;
    final aSpec = specialite != null && specialite.isNotEmpty;
    final aTexte = q != null && q.trim().isNotEmpty;
    if (!aWilaya && !aSpec && !aTexte) {
      return vitrine(page: page, limite: limite);
    }
    final r = await sb.rpc('chercher_praticiens', params: {
      'p_wilaya': aWilaya ? wilaya : null,
      'p_specialite': aSpec ? specialite : null,
      'p_q': aTexte ? q.trim() : null,
      'p_page': page,
      'p_limite': limite,
    });
    final lignes = r is Map ? r['lignes'] : null;
    return _mapListe(lignes);
  }

  /// Praticiens mis en avant (accueil), sans critere requis.
  Future<List<Map<String, dynamic>>> vitrine({int page = 1, int limite = 20}) async {
    final r = await sb.rpc('praticiens_vitrine', params: {
      'p_page': page,
      'p_limite': limite,
    });
    return _mapListe(r);
  }

  /// Statistiques publiques : total, listes des wilayas et specialites.
  Future<Map<String, dynamic>> stats() async {
    final r = await sb.rpc('stats_publiques');
    return (r as Map).cast<String, dynamic>();
  }

  /// Fiche d'un praticien par son identifiant.
  Future<Map<String, dynamic>?> parId(String id) async {
    final r = await sb.rpc('praticien', params: {'p_id': id});
    final liste = (r as List?) ?? const [];
    if (liste.isEmpty) return null;
    return _map(liste.first as Map);
  }
}
