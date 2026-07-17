import 'dart:io';

import 'release_tools.dart';

void main(List<String> arguments) {
  try {
    final options = _CoverageOptions.parse(arguments);
    final coverage = parseLcovCoverage(File(options.path).readAsStringSync());
    stdout.writeln(
      'Line coverage: ${coverage.percent.toStringAsFixed(2)}% '
      '(${coverage.hitLines}/${coverage.foundLines})',
    );
    if (!coverage.meets(options.minimum)) {
      stderr.writeln(
        '최소 line coverage ${options.minimum.toStringAsFixed(2)}% 미달',
      );
      exitCode = 1;
    }
  } on Object catch (error) {
    stderr.writeln('커버리지 검사 실패: $error');
    exitCode = 2;
  }
}

class _CoverageOptions {
  const _CoverageOptions({required this.path, required this.minimum});

  factory _CoverageOptions.parse(List<String> arguments) {
    var path = 'coverage/lcov.info';
    var minimum = 80.0;
    for (final argument in arguments) {
      if (argument.startsWith('--minimum=')) {
        minimum =
            double.tryParse(argument.substring('--minimum='.length)) ??
            (throw const FormatException('--minimum 값이 숫자가 아닙니다.'));
      } else if (!argument.startsWith('--')) {
        path = argument;
      } else {
        throw FormatException('알 수 없는 인수입니다: $argument');
      }
    }
    if (minimum < 0 || minimum > 100) {
      throw RangeError.range(minimum, 0, 100, 'minimum');
    }
    return _CoverageOptions(path: path, minimum: minimum);
  }

  final String path;
  final double minimum;
}
