/// Small formatting helpers shared across screens.
abstract final class Formatters {
  /// `1:05:09` or `05:09`.
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// `-12:04` style remaining time.
  static String remaining(Duration position, Duration total) {
    final left = total - position;
    return '-${duration(left.isNegative ? Duration.zero : left)}';
  }

  /// "12 min left" for continue-watching cards.
  static String minutesLeft(Duration position, Duration total) {
    final left = (total - position).inMinutes;
    if (left <= 0) return 'Almost done';
    return '$left min left';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static String price(double value) => '\$${value.toStringAsFixed(2)}';
}
