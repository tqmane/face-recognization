import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// 高度な設定画面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  
  late int _parallelDownloads;
  late int _cacheSize;
  late int _downloadTimeout;
  late int _targetImageSize;
  late bool _useReliableSourcesFirst;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  void _loadSettings() {
    _parallelDownloads = _settings.parallelDownloads;
    _cacheSize = _settings.cacheSize;
    _downloadTimeout = _settings.downloadTimeout;
    _targetImageSize = _settings.targetImageSize;
    _useReliableSourcesFirst = _settings.useReliableSourcesFirst;
  }
  
  void _saveSettings() {
    _settings.parallelDownloads = _parallelDownloads;
    _settings.cacheSize = _cacheSize;
    _settings.downloadTimeout = _downloadTimeout;
    _settings.targetImageSize = _targetImageSize;
    _settings.useReliableSourcesFirst = _useReliableSourcesFirst;
  }
  
  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設定をリセット'),
        content: const Text('すべての設定をデフォルト値に戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _settings.resetToDefaults();
      setState(() {
        _loadSettings();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定をリセットしました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('高度な設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'デフォルトに戻す',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // パフォーマンス設定セクション
          _buildSectionHeader('パフォーマンス設定', Icons.speed),
          const SizedBox(height: 8),
          
          _buildSliderTile(
            title: '並列ダウンロード数',
            subtitle: '同時にダウンロードする画像の数（低いほどメモリ節約）',
            value: _parallelDownloads.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            valueLabel: '$_parallelDownloads',
            onChanged: (value) {
              setState(() {
                _parallelDownloads = value.toInt();
              });
              _saveSettings();
            },
          ),
          
          _buildSliderTile(
            title: 'キャッシュサイズ',
            subtitle: 'メモリにキャッシュする画像の最大数',
            value: _cacheSize.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            valueLabel: '$_cacheSize',
            onChanged: (value) {
              setState(() {
                _cacheSize = value.toInt();
              });
              _saveSettings();
            },
          ),
          
          _buildSliderTile(
            title: 'ダウンロードタイムアウト',
            subtitle: '画像ダウンロードの待機時間（秒）',
            value: _downloadTimeout.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            valueLabel: '${_downloadTimeout}秒',
            onChanged: (value) {
              setState(() {
                _downloadTimeout = value.toInt();
              });
              _saveSettings();
            },
          ),
          
          const Divider(height: 32),
          
          // 画質設定セクション
          _buildSectionHeader('画質設定', Icons.image),
          const SizedBox(height: 8),
          
          _buildSliderTile(
            title: '目標画像サイズ',
            subtitle: 'ダウンロード時のリサイズ目標（大きいほど高画質、メモリ使用増）',
            value: _targetImageSize.toDouble(),
            min: 400,
            max: 1600,
            divisions: 12,
            valueLabel: '${_targetImageSize}px',
            onChanged: (value) {
              setState(() {
                _targetImageSize = value.toInt();
              });
              _saveSettings();
            },
          ),
          
          const Divider(height: 32),
          
          // 画像ソース設定セクション
          _buildSectionHeader('画像ソース設定', Icons.cloud_download),
          const SizedBox(height: 8),
          
          SwitchListTile(
            title: const Text('信頼性の高いソースを優先'),
            subtitle: const Text('iNaturalist, Dog API等を優先使用（より正確な画像）'),
            value: _useReliableSourcesFirst,
            onChanged: (value) {
              setState(() {
                _useReliableSourcesFirst = value;
              });
              _saveSettings();
            },
          ),
          
          const Divider(height: 32),
          
          // 情報セクション
          _buildSectionHeader('設定情報', Icons.info_outline),
          const SizedBox(height: 8),
          
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '現在の設定',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 並列ダウンロード: $_parallelDownloads\n'
                    '• キャッシュサイズ: $_cacheSize\n'
                    '• タイムアウト: ${_downloadTimeout}秒\n'
                    '• 画像サイズ: ${_targetImageSize}px\n'
                    '• 信頼ソース優先: ${_useReliableSourcesFirst ? "有効" : "無効"}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 注意書き
          Card(
            color: colorScheme.errorContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '設定変更は次回のテスト開始時から反映されます。\n'
                      '値を大きくするとメモリ不足になる可能性があります。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
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
  
  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    valueLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
