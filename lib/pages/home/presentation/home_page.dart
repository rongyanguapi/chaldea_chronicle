import 'package:flutter/material.dart';

import '../../../resource/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenStoryReaderPreview,
  });

  final VoidCallback onOpenStoryReaderPreview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaldea Chronicle'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.auto_stories_outlined,
                  size: 64,
                  color: AppColors.emphasis,
                ),
                const SizedBox(height: 20),
                Text(
                  '剧情阅读器预览',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onOpenStoryReaderPreview,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('预览序章剧情'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
