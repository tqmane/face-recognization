import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_sync_service.dart';

/// クラウド同期設定画面
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _syncService = FirebaseSyncService.instance;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // サインイン済みなら同期を開始
    if (_syncService.isSignedIn) {
      _syncService.setupRealtimeSync();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('クラウド同期'),
      ),
      body: StreamBuilder<User?>(
        stream: _syncService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          if (user == null) {
            return _buildSignedOutView();
          } else {
            return _buildSignedInView(user);
          }
        },
      ),
    );
  }
  
  Widget _buildSignedOutView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '☁️',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              'クラウド同期',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Googleアカウントでサインインして\n複数端末でテスト結果を同期しましょう',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Googleでサインイン'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSignedInView(User user) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ユーザー情報カード
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'サインイン済み',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  user.displayName ?? '名前なし',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'メールアドレスなし',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 同期セクション
        _buildSectionHeader('🔄 同期操作'),
        const SizedBox(height: 12),
        
        // アップロードボタン
        _buildActionCard(
          icon: '⬆️',
          title: '全データをアップロード',
          subtitle: 'ローカルのテスト結果をクラウドに保存',
          onTap: _uploadAllHistories,
        ),
        
        // ダウンロードボタン
        _buildActionCard(
          icon: '⬇️',
          title: '同期を開始',
          subtitle: 'クラウドのデータをリアルタイムで取得',
          onTap: () {
            _syncService.setupRealtimeSync();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('同期を開始しました')),
            );
          },
        ),
        
        const SizedBox(height: 24),
        
        // 危険ゾーン
        _buildSectionHeader('⚠️ 危険な操作', color: colorScheme.error),
        const SizedBox(height: 12),
        
        // クラウドデータ削除
        _buildActionCard(
          icon: '🗑️',
          title: 'クラウドデータを削除',
          subtitle: 'クラウド上の全データを削除（ローカルは保持）',
          titleColor: colorScheme.error,
          onTap: _showClearCloudConfirmDialog,
        ),
        
        const SizedBox(height: 16),
        
        // サインアウトボタン
        OutlinedButton(
          onPressed: _showSignOutConfirmDialog,
          child: const Text('サインアウト'),
        ),
        
        const SizedBox(height: 24),
        
        // 説明カード
        Card(
          color: colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('ℹ️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '同じGoogleアカウントでサインインすると、Android版とFlutter版でテスト結果が自動的に同期されます。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, {Color? color}) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
  
  Widget _buildActionCard({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await _syncService.signInWithGoogle();
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('サインインしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('サインインに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _uploadAllHistories() async {
    setState(() => _isLoading = true);
    
    try {
      final count = await _syncService.uploadAllHistories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count件のデータをアップロードしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アップロードに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showSignOutConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サインアウト'),
        content: const Text('サインアウトしますか？\nローカルのデータは保持されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _syncService.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('サインアウトしました')),
                );
              }
            },
            child: const Text('サインアウト'),
          ),
        ],
      ),
    );
  }
  
  void _showClearCloudConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('クラウドデータを削除'),
        content: const Text('クラウド上の全てのデータを削除しますか？\nローカルのデータは保持されます。\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                await _syncService.clearFirebaseHistories();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('クラウドデータを削除しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('削除に失敗しました: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }
}
