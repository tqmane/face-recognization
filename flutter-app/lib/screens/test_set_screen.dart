import 'package:flutter/material.dart';
import '../services/quiz_manager.dart';
import '../services/test_set_manager.dart';
import 'quiz_screen.dart';
import 'foul_edit_screen.dart';

class TestSetScreen extends StatefulWidget {
  const TestSetScreen({super.key});

  @override
  State<TestSetScreen> createState() => _TestSetScreenState();
}

class _TestSetScreenState extends State<TestSetScreen> {
  final TestSetManager _testSetManager = TestSetManager();
  List<TestSetInfo> _testSets = [];
  bool _isDownloading = false;
  int _downloadProgress = 0;
  int _downloadTotal = 0;
  String _downloadGenre = '';
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _loadTestSets();
  }

  Future<void> _loadTestSets() async {
    final sets = await _testSetManager.getAvailableTestSets();
    setState(() {
      _testSets = sets;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('テストセット'),
        centerTitle: true,
      ),
      body: _isDownloading ? _buildDownloadingView() : _buildNormalView(),
    );
  }

  Widget _buildNormalView() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 説明カード
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📦 テストセットとは？',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '事前に画像をダウンロードして保存しておくことで、ネット接続なしで素早くテストできます。一度作成すれば何度でも使えます。',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showBatteryOptimizationHelp,
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ダウンロードが遅い場合はこちら',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 新規作成ボタン
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _showGenreSelection,
                  icon: const Icon(Icons.add),
                  label: const Text('新しいテストセットを作成', style: TextStyle(fontSize: 17)),
                ),
              ),
              const SizedBox(height: 24),

              // セクションタイトル
              Text(
                '保存済みテストセット',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),

              // テストセット一覧
              if (_testSets.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'テストセットがありません\n上のボタンから作成してください',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_testSets.length, (index) {
                  final testSet = _testSets[index];
                  return _TestSetCard(
                    testSet: testSet,
                    onStartTest: () => _showQuestionCountDialog(testSet),
                    onDelete: () => _confirmDelete(testSet),
                    onEdit: () => _openFoulEdit(testSet),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              '$_downloadGenre をダウンロード中...',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$_downloadProgress / $_downloadTotal 問'),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _downloadTotal > 0 ? _downloadProgress / _downloadTotal : 0,
            ),
            const SizedBox(height: 8),
            Text('${_downloadTotal > 0 ? (_downloadProgress * 100 ~/ _downloadTotal) : 0}%'),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _cancelRequested = true;
                  _isDownloading = false;
                });
              },
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenreSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ダウンロードするジャンル'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: Genre.values.map((genre) {
              return ListTile(
                title: Text(genre.displayName),
                onTap: () {
                  Navigator.pop(context);
                  _showQuestionCountSelection(genre);
                },
              );
            }).toList(),
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

  void _showQuestionCountSelection(Genre genre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ダウンロードする問題数'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              ('50問', 50),
              ('100問', 100),
              ('200問', 200),
            ])
              ListTile(
                title: Text(option.$1),
                onTap: () {
                  Navigator.pop(context);
                  _startDownload(genre, option.$2);
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showGenreSelection();
            },
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload(Genre genre, int totalQuestions) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadTotal = totalQuestions;
      _downloadGenre = genre.displayName;
      _cancelRequested = false;
    });

    int lastProgress = 0;
    final success = await _testSetManager.createTestSet(
      genre: genre,
      totalQuestions: totalQuestions,
      onProgress: (current, total) {
        // 進捗が減ることはないはずなので、増加時のみ更新
        if (mounted && current > lastProgress && !_cancelRequested) {
          lastProgress = current;
          setState(() {
            _downloadProgress = current;
          });
        }
      },
    );

    if (mounted && !_cancelRequested) {
      setState(() {
        _isDownloading = false;
      });

      if (success > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${genre.displayName}の$success問を保存しました')),
        );
        _loadTestSets();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ダウンロードに失敗しました')),
        );
      }
    }
  }

  void _showQuestionCountDialog(TestSetInfo testSet) {
    final maxQuestions = testSet.questionCount;
    final options = <(String, int)>[];
    
    if (maxQuestions >= 5) options.add(('5問（お試し）', 5));
    if (maxQuestions >= 10) options.add(('10問', 10));
    if (maxQuestions >= 20) options.add(('20問', 20));
    if (maxQuestions >= 50) options.add(('50問', 50));
    options.add(('全問（$maxQuestions問）', maxQuestions));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('問題数を選択'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            return ListTile(
              title: Text(option.$1),
              onTap: () {
                Navigator.pop(context);
                // テストセットのジャンル名からGenreを特定
                final genre = Genre.values.firstWhere(
                  (g) => g.displayName == testSet.genreName,
                  orElse: () => Genre.all,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      genre: genre,
                      questionCount: option.$2,
                      testSet: testSet, // テストセット情報を渡す
                    ),
                  ),
                );
              },
            );
          }).toList(),
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

  void _confirmDelete(TestSetInfo testSet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${testSet.genreName}」(${testSet.questionCount}問)を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _testSetManager.deleteTestSet(testSet);
              _loadTestSets();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('削除しました')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _openFoulEdit(TestSetInfo testSet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoulEditScreen(testSet: testSet),
      ),
    );
    // 戻ってきたら再読み込み
    _loadTestSets();
  }

  void _showBatteryOptimizationHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert),
            SizedBox(width: 8),
            Text('ダウンロードが遅い場合'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '一部のデバイスでは省電力機能により、アプリのネットワーク通信が制限されることがあります。',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                '以下の設定をお試しください：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. 設定アプリを開く'),
              Text('2. 「バッテリー」または「電池」を選択'),
              Text('3. 「バッテリー最適化」を探す'),
              Text('4. このアプリを「最適化しない」に設定'),
              SizedBox(height: 16),
              Text(
                '【OnePlus / OPPO / realme の場合】',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '設定 → アプリ → このアプリ → バッテリー使用量 → 「制限なし」を選択',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '【Samsung の場合】',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '設定 → バッテリー → バッテリーを最適化 → このアプリを「除外」',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '※ ダウンロード中は画面をオンにしておくことをおすすめします。',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

class _TestSetCard extends StatelessWidget {
  final TestSetInfo testSet;
  final VoidCallback onStartTest;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TestSetCard({
    required this.testSet,
    required this.onStartTest,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('📁', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testSet.genreName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${testSet.questionCount}問 | ${_formatDate(testSet.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onStartTest,
                    child: const Text('テスト開始'),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onEdit,
                  child: const Text('編集'),
                ),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('削除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
