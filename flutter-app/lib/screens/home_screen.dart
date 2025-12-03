import 'package:flutter/material.dart';
import 'zip_quiz_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../services/zip_test_set_service.dart';
import '../services/history_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await HistoryManager.instance.loadHistories();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final stats = HistoryManager.instance.getOverallStats();
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // 設定ボタン（左上）
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: '設定',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
            ),
            // メインコンテンツ
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // アイコン
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text(
                        '🔍',
                        style: TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // タイトル
                  Text(
                    '判別クイズ',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '似てる？同じ？判断しよう',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // 統計カード
                  Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistoryScreen()),
                        ).then((_) => setState(() {}));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '📊 テスト結果',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right, color: colorScheme.onSurface.withOpacity(0.4)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (stats.totalTests > 0) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '平均正答率',
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
                                        ),
                                        Text(
                                          '${stats.averageAccuracy.toStringAsFixed(1)}%',
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'テスト回数',
                                          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.6)),
                                        ),
                                        Text(
                                          '${stats.totalTests}回',
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              Text(
                                'まだ記録がありません',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // テストセット選択ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => _showTestSetSelection(context),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('テスト開始', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // テストセット管理ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TestSetDownloadScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('テストセット管理', style: TextStyle(fontSize: 17)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'テストセットをダウンロードして開始',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int millis) {
    final seconds = millis ~/ 1000;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes分$secs秒';
    }
    return '$secs秒';
  }

  void _showTestSetSelection(BuildContext context) async {
    final service = ZipTestSetService();
    final downloadedSets = await service.getDownloadedTestSets();
    
    if (!mounted) return;
    
    if (downloadedSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('テストセットがありません。まずダウンロードしてください。'),
          action: SnackBarAction(
            label: 'ダウンロード',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestSetDownloadScreen()),
              );
            },
          ),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('テストセットを選択'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: downloadedSets.length,
            itemBuilder: (context, index) {
              final testSet = downloadedSets[index];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(testSet.displayName),
                subtitle: Text('${testSet.imageCount ?? 0}枚の画像'),
                onTap: () {
                  Navigator.pop(context);
                  _showQuestionCountDialog(context, testSet);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _showQuestionCountDialog(BuildContext context, ZipTestSetInfo testSet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${testSet.displayName} - 問題数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              ('5問（お試し）', 5),
              ('10問', 10),
              ('15問', 15),
              ('20問', 20),
            ])
              ListTile(
                title: Text(option.$1),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ZipQuizScreen(
                        testSetId: testSet.id,
                        testSetName: testSet.displayName,
                        questionCount: option.$2,
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showTestSetSelection(context);
            },
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }
}

/// テストセットダウンロード画面
class TestSetDownloadScreen extends StatefulWidget {
  const TestSetDownloadScreen({super.key});

  @override
  State<TestSetDownloadScreen> createState() => _TestSetDownloadScreenState();
}

class _TestSetDownloadScreenState extends State<TestSetDownloadScreen> {
  final ZipTestSetService _service = ZipTestSetService();
  Map<String, bool> _downloadedMap = {};
  Map<String, double> _downloadProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    final downloaded = await _service.getDownloadedTestSets();
    setState(() {
      _downloadedMap = {
        for (final set in downloaded) set.id: true,
      };
      _isLoading = false;
    });
  }

  Future<void> _downloadTestSet(ZipTestSetInfo testSet) async {
    setState(() {
      _downloadProgress[testSet.id] = 0.0;
    });
    
    try {
      await _service.downloadTestSet(
        testSet,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress[testSet.id] = progress;
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          _downloadedMap[testSet.id] = true;
          _downloadProgress.remove(testSet.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${testSet.displayName} をダウンロードしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(testSet.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ダウンロードエラー: $e')),
        );
      }
    }
  }

  Future<void> _deleteTestSet(ZipTestSetInfo testSet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${testSet.displayName} を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _service.deleteTestSet(testSet.id);
      setState(() {
        _downloadedMap[testSet.id] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${testSet.displayName} を削除しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('テストセット管理'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ZipTestSetService.availableTestSets.length,
              itemBuilder: (context, index) {
                final testSet = ZipTestSetService.availableTestSets[index];
                final isDownloaded = _downloadedMap[testSet.id] ?? false;
                final progress = _downloadProgress[testSet.id];
                final isDownloading = progress != null;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDownloaded
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        isDownloaded ? Icons.check : Icons.download,
                        color: isDownloaded
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    title: Text(testSet.displayName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(testSet.description),
                        if (isDownloading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(value: progress),
                          ),
                      ],
                    ),
                    trailing: isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isDownloaded
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteTestSet(testSet),
                              )
                            : IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () => _downloadTestSet(testSet),
                              ),
                  ),
                );
              },
            ),
    );
  }
}
