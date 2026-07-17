class LcovCoverage {
  const LcovCoverage({required this.hitLines, required this.foundLines});

  final int hitLines;
  final int foundLines;

  double get percent => hitLines * 100 / foundLines;

  bool meets(double minimumPercent) {
    if (minimumPercent < 0 || minimumPercent > 100) {
      throw RangeError.range(minimumPercent, 0, 100, 'minimumPercent');
    }
    return percent >= minimumPercent;
  }
}

LcovCoverage parseLcovCoverage(String content) {
  var foundLines = 0;
  var hitLines = 0;
  var foundSummaries = 0;
  var hitSummaries = 0;
  for (final line in content.split(RegExp(r'\r?\n'))) {
    if (line.startsWith('LF:')) {
      foundLines += _parseSummary(line, 'LF:');
      foundSummaries++;
    } else if (line.startsWith('LH:')) {
      hitLines += _parseSummary(line, 'LH:');
      hitSummaries++;
    }
  }
  if (foundSummaries == 0 || hitSummaries == 0 || foundLines == 0) {
    throw const FormatException('LCOV line summary가 비어 있습니다.');
  }
  if (hitLines > foundLines) {
    throw const FormatException('LCOV hit line 수가 전체 line 수보다 큽니다.');
  }
  return LcovCoverage(hitLines: hitLines, foundLines: foundLines);
}

int _parseSummary(String line, String prefix) {
  final value = int.tryParse(line.substring(prefix.length));
  if (value == null || value < 0) {
    throw FormatException('잘못된 LCOV summary입니다: $line');
  }
  return value;
}

class WindowsAppcastEntry {
  WindowsAppcastEntry({
    required this.version,
    required this.downloadUrl,
    required this.dsaSignature,
    required this.length,
    required this.publishedAt,
    this.releaseNotesUrl,
  }) {
    if (version.trim().isEmpty) {
      throw ArgumentError.value(version, 'version', '비어 있을 수 없습니다.');
    }
    _validateHttps(downloadUrl, 'downloadUrl');
    if (releaseNotesUrl case final url?) {
      _validateHttps(url, 'releaseNotesUrl');
    }
    if (dsaSignature.trim().isEmpty) {
      throw ArgumentError.value(dsaSignature, 'dsaSignature', '비어 있을 수 없습니다.');
    }
    if (length <= 0) {
      throw RangeError.range(length, 1, null, 'length');
    }
  }

  final String version;
  final Uri downloadUrl;
  final String dsaSignature;
  final int length;
  final DateTime publishedAt;
  final Uri? releaseNotesUrl;
}

String renderWindowsAppcast(WindowsAppcastEntry entry) {
  final notes = switch (entry.releaseNotesUrl) {
    final Uri url =>
      '''
      <sparkle:releaseNotesLink>${_escapeXml(url.toString())}</sparkle:releaseNotesLink>''',
    null => '',
  };
  final version = _escapeXml(entry.version);
  return '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Discord Native</title>
    <description>Discord Native Windows updates</description>
    <language>ko</language>
    <item>
      <title>Version $version</title>$notes
      <pubDate>${_formatRfc822(entry.publishedAt.toUtc())}</pubDate>
      <enclosure url="${_escapeXml(entry.downloadUrl.toString())}"
                 sparkle:dsaSignature="${_escapeXml(entry.dsaSignature)}"
                 sparkle:version="$version"
                 sparkle:os="windows"
                 length="${entry.length}"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
''';
}

void _validateHttps(Uri uri, String name) {
  if (uri.scheme != 'https' || uri.host.isEmpty) {
    throw ArgumentError.value(uri, name, '유효한 HTTPS URL이어야 합니다.');
  }
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

String _formatRfc822(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int number) => number.toString().padLeft(2, '0');
  return '${weekdays[value.weekday - 1]}, ${two(value.day)} '
      '${months[value.month - 1]} ${value.year} ${two(value.hour)}:'
      '${two(value.minute)}:${two(value.second)} GMT';
}
