import 'package:flutter/material.dart';
import '../services/firebase_sync_service.dart';
import 'sync_screen.dart';
import 'admin_screen.dart';

/// 設定画面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // クラウド同期セクション
          _buildSectionHeader('クラウド同期', Icons.cloud_sync),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                FirebaseSyncService.instance.isSignedIn 
                    ? Icons.check_circle 
                    : Icons.sync,
                color: FirebaseSyncService.instance.isSignedIn
                    ? Colors.green
                    : colorScheme.primary,
              ),
              title: const Text('クラウド同期設定'),
              subtitle: Text(
                FirebaseSyncService.instance.isSignedIn
                    ? '✓ ${FirebaseSyncService.instance.userEmail ?? "ログイン中"}'
                    : 'Googleアカウントでテスト結果を同期',
                style: TextStyle(
                  color: FirebaseSyncService.instance.isSignedIn
                      ? Colors.green
                      : null,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SyncScreen()),
                ).then((_) => setState(() {}));
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.admin_panel_settings,
                color: colorScheme.secondary,
              ),
              title: const Text('管理者画面'),
              subtitle: const Text('全ユーザーのプレイデータを閲覧'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // アプリ情報セクション
          _buildSectionHeader('アプリ情報', Icons.info_outline),
          const SizedBox(height: 8),
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '類似度クイズ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '似ている動物の画像を見比べて、同じ種類か違う種類かを当てるクイズアプリです。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'バージョン: 2.0.0+1',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
