// notifications_push.dart — service Push/FCM Tabibi (PRET A ACTIVER)
//
// INACTIF tant que android/app/google-services.json n'est pas depose.
// Activation : voir fcm/ACTIVATION.md. Une fois les deps decommentees dans
// pubspec.yaml, deplacer ce fichier dans lib/services/ puis appeler
// NotificationsPush.initialiser() apres Supabase.initialize() dans main().
//
// Se degrade proprement : si Firebase n'est pas configure, initialiser()
// attrape l'erreur et l'app continue sans push (aucun crash).

import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handler messages en arriere-plan (doit etre une fonction top-level).
@pragma('vm:entry-point')
Future<void> _handlerArrierePlan(RemoteMessage message) async {
  // Le systeme affiche deja la notification « notification » en arriere-plan.
  // Rien a faire ici sauf logique metier eventuelle.
}

class NotificationsPush {
  static final _fln = FlutterLocalNotificationsPlugin();
  static const _canal = AndroidNotificationChannel(
    'tabibi_default',
    'Notifications Tabibi',
    description: 'Rappels de rendez-vous, teleconsultation, messages',
    importance: Importance.high,
  );

  static bool _pret = false;

  /// A appeler apres Supabase.initialize(). Ne jette jamais.
  static Future<void> initialiser() async {
    try {
      await Firebase.initializeApp();

      // Canal Android + init du plugin local (affichage en premier plan)
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_canal);
      await _fln.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));

      FirebaseMessaging.onBackgroundMessage(_handlerArrierePlan);

      // Permission (iOS + Android 13+)
      await FirebaseMessaging.instance.requestPermission();

      // Enregistre le token courant + a chaque rafraichissement
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _enregistrerToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_enregistrerToken);

      // Message recu app au premier plan -> notification locale
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        _fln.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(_canal.id, _canal.name,
                channelDescription: _canal.description,
                importance: Importance.high,
                priority: Priority.high),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      });

      _pret = true;
    } catch (e) {
      // Firebase non configure (pas de google-services.json) -> push desactive.
      _pret = false;
    }
  }

  /// Upsert du token dans public.device_tokens (unique sur user_id + token).
  static Future<void> _enregistrerToken(String token) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('device_tokens').upsert({
        'user_id': uid,
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
    } catch (_) {/* best-effort */}
  }

  static bool get estPret => _pret;
}
