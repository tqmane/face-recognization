import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/test_set_manager.dart';
import '../services/quiz_manager.dart';
import '../services/image_scraper.dart';

/// テストセットの画像を編集（不適切な画像を削除）する画面
class FoulEditScreen extends StatefulWidget {
  final TestSetInfo testSet;

  const FoulEditScreen({super.key, required this.testSet});

  @override
  State<FoulEditScreen> createState() => _FoulEditScreenState();
}

class _FoulEditScreenState extends State<FoulEditScreen> {
  List<_QuestionItem> _questions = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = true;
  bool _isDownloading = false;
  int _downloadProgress = 0;
  int _downloadTotal = 0;
  
  // 選択モードかどうか（最初の長押しで有効化）
  bool _isSelectionMode = false;
  
  final QuizManager _quizManager = QuizManager();
  final ImageScraper _scraper = ImageScraper();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _isSelectionMode = false;
    });

    try {
      final questionsFile = File('${widget.testSet.dirPath}/questions.json');
      if (await questionsFile.exists()) {
        final content = await questionsFile.readAsString();
        final List<dynamic> json = jsonDecode(content);
        
        _questions = [];
        for (int i = 0; i < json.length; i++) {
          final q = json[i];
          final imagePath = '${widget.testSet.dirPath}/${q['imagePath']}';
          if (await File(imagePath).exists()) {
            _questions.add(_QuestionItem(
              index: i,
              imagePath: imagePath,
              isSame: q['isSame'] ?? false,
              description: q['description'] ?? '',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('読み込みエラー: $e');
    }

    setState(() => _isLoading = false);
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
      // 選択が全て解除されたら選択モードを終了
      if (_selectedIndices.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }
  
  /// 画像タップ時の処理
  /// - 選択モード中: 選択切り替え
  /// - 選択モードでない: プレビュー表示
  void _onImageTap(int index) {
    if (_isSelectionMode) {
      _toggleSelection(index);
    } else {
      _showImagePreview(index);
    }
  }
  
  /// 画像長押し時の処理
  /// - 選択モード中: プレビュー表示
  /// - 選択モードでない: 選択モード開始 & 選択
  void _onImageLongPress(int index) {
    if (_isSelectionMode) {
      _showImagePreview(index);
    } else {
      setState(() {
        _isSelectionMode = true;
      });
      _toggleSelection(index);
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == _questions.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.clear();
        for (int i = 0; i < _questions.length; i++) {
          _selectedIndices.add(i);
        }
      }
    });
  }

  void _showImagePreview(int index) {
    final question = _questions[index];
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: Text('問題 ${index + 1}'),
            actions: [
              IconButton(
                icon: Icon(
                  _selectedIndices.contains(index) 
                      ? Icons.check_circle 
                      : Icons.check_circle_outline,
                  color: _selectedIndices.contains(index) ? Colors.red : Colors.white,
                ),
                onPressed: () {
                  _toggleSelection(index);
                  Navigator.pop(context);
                },
                tooltip: '削除対象に追加/解除',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                File(question.imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    question.description,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正解: ${question.isSame ? "同じ" : "違う"}',
                    style: TextStyle(
                      color: question.isSame ? Colors.green : Colors.orange,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final count = _selectedIndices.length;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('$count枚の画像を削除しますか？\n（テストセットの問題数が減少します）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSelected();
    }
  }

  Future<void> _deleteSelected() async {
    try {
      // 削除対象のインデックス（降順でソート）
      final toDelete = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      
      // 画像ファイルを削除
      for (final index in toDelete) {
        final question = _questions[index];
        final file = File(question.imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // 残りの問題を取得
      final remaining = <_QuestionItem>[];
      for (int i = 0; i < _questions.length; i++) {
        if (!_selectedIndices.contains(i)) {
          remaining.add(_questions[i]);
        }
      }

      // questions.jsonを更新
      final newQuestions = <Map<String, dynamic>>[];
      for (int i = 0; i < remaining.length; i++) {
        final q = remaining[i];
        final newImagePath = 'question_$i.png';
        
        // 画像ファイルをリネーム
        final oldFile = File(q.imagePath);
        final newFile = File('${widget.testSet.dirPath}/$newImagePath');
        if (await oldFile.exists() && oldFile.path != newFile.path) {
          await oldFile.rename(newFile.path);
        }
        
        newQuestions.add({
          'index': i,
          'isSame': q.isSame,
          'description': q.description,
          'imagePath': newImagePath,
        });
      }

      final questionsFile = File('${widget.testSet.dirPath}/questions.json');
      await questionsFile.writeAsString(jsonEncode(newQuestions));

      // metadata.jsonを更新
      await _updateMetadata(remaining.length);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toDelete.length}枚を削除しました')),
        );
      }

      // リストを再読み込み
      _selectedIndices.clear();
      await _loadQuestions();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除エラー: $e')),
        );
      }
    }
  }

  Future<void> _updateMetadata(int newCount) async {
    try {
      final metadataFile = File('${widget.testSet.dirPath}/metadata.json');
      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        json['questionCount'] = newCount;
        await metadataFile.writeAsString(jsonEncode(json));
      }
    } catch (e) {
      debugPrint('メタデータ更新エラー: $e');
    }
  }

  /// 追加ダウンロードダイアログを表示
  void _showAddMoreDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('追加ダウンロード'),
        content: Text('現在 ${_questions.length} 問あります。\n追加でダウンロードする問題数を選択してください。'),
        actions: [
          for (final option in [
            ('5問追加', 5),
            ('10問追加', 10),
            ('20問追加', 20),
          ])
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startAdditionalDownload(option.$2);
              },
              child: Text(option.$1),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  /// 追加ダウンロードを開始
  Future<void> _startAdditionalDownload(int addCount) async {
    // ジャンルを特定
    final genre = Genre.values.firstWhere(
      (g) => g.displayName == widget.testSet.genreName,
      orElse: () => Genre.all,
    );

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadTotal = addCount;
    });

    _scraper.clearUsedUrls();

    try {
      final startIndex = _questions.length;
      int successCount = 0;
      final maxAttempts = addCount * 3;

      for (int attempt = 0; attempt < maxAttempts && successCount < addCount; attempt++) {
        if (!_isDownloading) break;

        final config = _quizManager.generateQuestion(genre: genre);

        try {
          final imageData = config.isSame
              ? await _scraper.createSameImage(config.query1)
              : await _scraper.createComparisonImage(config.query1, config.query2);

          if (imageData != null) {
            final newIndex = startIndex + successCount;
            final imagePath = 'question_$newIndex.png';
            final imageFile = File('${widget.testSet.dirPath}/$imagePath');
            await imageFile.writeAsBytes(imageData);

            // questions.jsonに追加
            final questionsFile = File('${widget.testSet.dirPath}/questions.json');
            List<dynamic> existingQuestions = [];
            if (await questionsFile.exists()) {
              final content = await questionsFile.readAsString();
              existingQuestions = jsonDecode(content);
            }
            existingQuestions.add({
              'index': newIndex,
              'isSame': config.isSame,
              'description': config.description,
              'imagePath': imagePath,
            });
            await questionsFile.writeAsString(jsonEncode(existingQuestions));

            successCount++;
            if (mounted) {
              setState(() {
                _downloadProgress = successCount;
              });
            }
          }
        } catch (e) {
          debugPrint('ダウンロードエラー: $e');
        }
      }

      // メタデータを更新
      await _updateMetadata(startIndex + successCount);

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$successCount問を追加しました')),
          );
          _selectedIndices.clear();
          await _loadQuestions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('追加ダウンロードに失敗しました')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.testSet.genreName} の編集'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    // ヘッダー
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '全${_questions.length}問',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedIndices.isEmpty
                                ? '画像を長押しで削除選択'
                                : '${_selectedIndices.length}件選択中',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSelectionMode
                                ? '💡 タップで選択・長押しで拡大表示'
                                : '💡 タップで拡大表示・長押しで選択開始',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // 画像グリッド
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) => _buildImageCard(index),
                      ),
                    ),
                    
                    // 下部ボタン
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 追加ダウンロードボタン
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isDownloading ? null : _showAddMoreDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('追加ダウンロード'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _toggleSelectAll,
                                    child: Text(
                                      _selectedIndices.length == _questions.length
                                          ? '全選択解除'
                                          : '全選択',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _selectedIndices.isEmpty ? null : _confirmDelete,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('削除'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // ダウンロード中オーバーレイ
                if (_isDownloading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text('ダウンロード中... $_downloadProgress / $_downloadTotal'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildImageCard(int index) {
    final question = _questions[index];
    final isSelected = _selectedIndices.contains(index);

    return GestureDetector(
      onTap: () => _onImageTap(index),
      onLongPress: () => _onImageLongPress(index),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 画像（全体表示）
            Container(
              color: Colors.grey[200],
              child: Image.file(
                File(question.imagePath),
                fit: BoxFit.contain,
                cacheWidth: 300,
              ),
            ),
            
            // インデックス番号
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            
            // 選択オーバーレイ
            if (isSelected)
              Container(
                color: Colors.red.withOpacity(0.5),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionItem {
  final int index;
  final String imagePath;
  final bool isSame;
  final String description;

  _QuestionItem({
    required this.index,
    required this.imagePath,
    required this.isSame,
    required this.description,
  });
}
