class StoryRepositoryException implements Exception {
  const StoryRepositoryException(
    this.message, {
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'StoryRepositoryException: $message';
    }
    return 'StoryRepositoryException: $message ($cause)';
  }
}
