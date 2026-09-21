import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration Supabase. La cle « anon » est PUBLIQUE (protegee par les regles RLS
/// de la base) : elle peut figurer dans l'app, comme sur le site tabibi.doctor.
const String supabaseUrl = 'https://pudugodhiofqrctcdwfl.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB1ZHVnb2RoaW9mcXJjdGNkd2ZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNzUwNzAsImV4cCI6MjA5Mzc1MTA3MH0.XUmkPhXN8W0bX9L2-MVPuqWVjOsNP69zDqTF2XpR0U4';

/// Client Supabase partage par toute l'application.
SupabaseClient get sb => Supabase.instance.client;

/// Cle de navigation globale : permet aux services (ex. AuthService) d'ouvrir un
/// ecran (connexion) sans disposer d'un BuildContext.
final GlobalKey<NavigatorState> navigatorCle = GlobalKey<NavigatorState>();

/// A appeler une fois au demarrage (avant runApp).
Future<void> initialiserSupabase() =>
    Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
