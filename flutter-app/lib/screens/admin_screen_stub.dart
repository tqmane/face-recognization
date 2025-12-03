import 'package:flutter/material.dart';

/// デスクトップ/Web向けのスタブ実装
/// Firebase非対応プラットフォームでは管理者画面は利用不可

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者画面')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.desktop_windows, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '管理者画面はモバイルアプリ\n（Android/iOS）でのみ利用可能です',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Firebase認証が必要なため、\nデスクトップ版では対応していません',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
