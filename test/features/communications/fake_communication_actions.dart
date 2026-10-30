import 'dart:async';

import 'package:mi_red/features/communications/communication_actions.dart';

class FakeCommunicationActions implements CommunicationActions {
  final opened = <Uri>[];
  final copied = <String>[];
  final shared = <String>[];
  bool openResult = false, failOpen = false, failShare = false;
  ShareOutcome outcome = ShareOutcome.dismissed;
  Completer<void>? gate;
  @override
  Future<bool> openLink(Uri uri) async {
    opened.add(uri);
    if (gate != null) await gate!.future;
    if (failOpen) throw StateError('Fallo sintético de enlace');
    return openResult;
  }

  @override
  Future<void> copyText(String text) async {
    copied.add(text);
  }

  @override
  Future<ShareOutcome> shareText(String text) async {
    shared.add(text);
    if (gate != null) await gate!.future;
    if (failShare) throw StateError('Fallo sintético de compartir');
    return outcome;
  }
}
