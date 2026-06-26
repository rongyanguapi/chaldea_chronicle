import 'package:flutter/material.dart';

import 'pages/home/presentation/home_page.dart';
import 'pages/story_reader/presentation/story_reader_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const String root = '/';
  static const String storyReaderPreview = '/story-reader/preview';
  static const String _previewScriptId = '0100061710';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      root => _buildRoute(
          settings,
          builder: (context) => HomePage(
            onOpenStoryReaderPreview: () => openStoryReaderPreview(context),
          ),
        ),
      storyReaderPreview => _buildRoute(
          settings,
          builder: (context) => StoryReaderPage(
            scriptId: _storyReaderScriptId(settings.arguments),
            onBack: () => pop(context),
          ),
        ),
      _ => _buildRoute(
          settings,
          builder: (context) => const _UnknownRoutePage(),
        ),
    };
  }

  static Future<T?> openStoryReaderPreview<T>(BuildContext context) {
    return Navigator.of(context).pushNamed<T>(
      storyReaderPreview,
      arguments: const StoryReaderRouteArguments(
        scriptId: _previewScriptId,
      ),
    );
  }

  static void pop(BuildContext context) {
    Navigator.of(context).maybePop();
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    RouteSettings settings, {
    required WidgetBuilder builder,
  }) {
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: builder,
    );
  }

  static String _storyReaderScriptId(Object? arguments) {
    if (arguments is StoryReaderRouteArguments) {
      return arguments.scriptId;
    }
    return _previewScriptId;
  }
}

class StoryReaderRouteArguments {
  const StoryReaderRouteArguments({
    required this.scriptId,
  });

  final String scriptId;
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('页面不存在'),
      ),
    );
  }
}
