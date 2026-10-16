import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../theme/theme_tabibi.dart';

/// Salle de téléconsultation embarquée dans l'app (WebView chargeant la salle
/// Daily). La caméra et le micro sont autorisés automatiquement dans la WebView.
/// Un repli « ouvrir dans le navigateur » reste disponible.
class TeleconsultationPage extends StatefulWidget {
  const TeleconsultationPage({super.key, required this.salleUrl, this.titre = 'Téléconsultation'});

  final String salleUrl;
  final String titre;

  @override
  State<TeleconsultationPage> createState() => _TeleconsultationPageState();
}

class _TeleconsultationPageState extends State<TeleconsultationPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    late final PlatformWebViewControllerCreationParams params;
    params = const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params);
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onWebResourceError: (e) {
          if (mounted) setState(() => _erreur = true);
        },
      ))
      ..loadRequest(Uri.parse(widget.salleUrl));

    // Android : accorder automatiquement les demandes caméra/micro de la salle Daily.
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
      android.setOnPlatformPermissionRequest((request) => request.grant());
    }
    _controller = controller;
  }

  Future<void> _ouvrirNavigateur() async {
    try {
      await launchUrl(Uri.parse(widget.salleUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.titre),
        actions: [
          IconButton(
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: _ouvrirNavigateur,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: _erreur
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 48),
                  const SizedBox(height: 12),
                  const Text('Impossible de charger la salle vidéo ici.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Tabibi.vert),
                    onPressed: _ouvrirNavigateur,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir dans le navigateur'),
                  ),
                ]),
              ),
            )
          : Stack(children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    backgroundColor: Colors.black,
                    color: Tabibi.vert,
                  ),
                ),
            ]),
    );
  }
}
