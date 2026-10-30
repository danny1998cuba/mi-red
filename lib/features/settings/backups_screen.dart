import 'package:flutter/widgets.dart';

import '../backups/backup_section.dart';
import 'settings_page.dart';

class BackupsScreen extends StatelessWidget {
  const BackupsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SettingsPage(
    title: 'Copias de seguridad',
    child: BackupSection(showHeading: false),
  );
}
