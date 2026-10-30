import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareOutcome { selected, dismissed, unavailable }

abstract class CommunicationActions {
  Future<bool> openLink(Uri uri);
  Future<ShareOutcome> shareText(String text);
  Future<void> copyText(String text);
}

class SystemCommunicationActions implements CommunicationActions {
  @override
  Future<bool> openLink(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
  @override
  Future<ShareOutcome> shareText(String text) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, title: 'Mi Red'),
    );
    return switch (result.status) {
      ShareResultStatus.success => ShareOutcome.selected,
      ShareResultStatus.dismissed => ShareOutcome.dismissed,
      ShareResultStatus.unavailable => ShareOutcome.unavailable,
    };
  }
}

final communicationActionsProvider = Provider<CommunicationActions>(
  (ref) => SystemCommunicationActions(),
);

String shareOutcomeMessage(ShareOutcome outcome) => switch (outcome) {
  ShareOutcome.selected =>
    'Se eligió una aplicación. Esto no confirma envío ni entrega.',
  ShareOutcome.dismissed => 'Compartir cancelado.',
  ShareOutcome.unavailable => 'El panel se cerró sin confirmación de envío.',
};
