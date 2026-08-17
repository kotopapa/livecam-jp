import 'package:flutter/material.dart';

void main() {
  runApp(const LiveCamApp());
}

class LiveCamApp extends StatelessWidget {
  const LiveCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '全国ライブカメラ地図',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const PlaceholderScreen(),
    );
  }
}

/// データ層・地図画面の実装までの仮画面。
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全国ライブカメラ地図')),
      body: const Center(child: Text('実装準備中')),
    );
  }
}
