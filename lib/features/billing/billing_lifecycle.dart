import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_maintenance.dart';

import 'billing_providers.dart';
import '../reminders/reminder_providers.dart';

class BillingLifecycle extends ConsumerStatefulWidget {
  const BillingLifecycle({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<BillingLifecycle> createState() => _BillingLifecycleState();
}

class _BillingLifecycleState extends ConsumerState<BillingLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(billingSessionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(remindersProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (ref.read(databaseMaintenanceProvider).active) return;
      unawaited(ref.read(billingSessionProvider.notifier).refresh());
      unawaited(ref.read(remindersProvider.notifier).refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
