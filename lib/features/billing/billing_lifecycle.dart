import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'billing_providers.dart';

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(billingSessionProvider.notifier).refresh());
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
