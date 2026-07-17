import 'dart:io';

import 'release_tools.dart';

void main(List<String> arguments) {
  try {
    final values = _parseArguments(arguments);
    final output = File(_required(values, 'output'));
    final entry = WindowsAppcastEntry(
      version: _required(values, 'version'),
      downloadUrl: Uri.parse(_required(values, 'url')),
      dsaSignature: _required(values, 'signature'),
      length:
          int.tryParse(_required(values, 'length')) ??
          (throw const FormatException('--length 값이 정수가 아닙니다.')),
      publishedAt: DateTime.now().toUtc(),
      releaseNotesUrl: switch (values['release-notes']) {
        final String value => Uri.parse(value),
        null => null,
      },
    );
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(renderWindowsAppcast(entry));
    stdout.writeln(output.path);
  } on Object catch (error) {
    stderr.writeln('appcast 생성 실패: $error');
    exitCode = 2;
  }
}

Map<String, String> _parseArguments(List<String> arguments) {
  final values = <String, String>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) {
      throw FormatException('인수는 --name=value 형식이어야 합니다: $argument');
    }
    final separator = argument.indexOf('=');
    values[argument.substring(2, separator)] = argument.substring(
      separator + 1,
    );
  }
  return Map.unmodifiable(values);
}

String _required(Map<String, String> values, String name) {
  final value = values[name];
  if (value == null || value.trim().isEmpty) {
    throw FormatException('--$name 값이 필요합니다.');
  }
  return value;
}
