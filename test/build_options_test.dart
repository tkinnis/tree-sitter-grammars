import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/build_options.dart';
import '../tool/src/build_platform.dart';

void main() {
  test('a plain build, a dry run and a publish are as they were', () {
    check(
      parseBuildArguments([]),
    ).isNotNull().has((o) => o.mode, 'mode').equals(BuildMode.build);
    check(
      parseBuildArguments(['--release=v1.1.0', '--dry-run']),
    ).isNotNull().has((o) => o.dryRun, 'dryRun').isTrue();
    check(
      parseBuildArguments(['--release=v1.1.0', '--publish']),
    ).isNotNull().has((o) => o.publish, 'publish').isTrue();
  });

  test('--attach builds from --sources, then attaches', () {
    final options = parseBuildArguments([
      '--release=v1.1.0',
      '--sources=../assets',
      '--attach',
    ]);

    check(options).isNotNull()
      ..has((o) => o.mode, 'mode').equals(BuildMode.attach)
      ..has((o) => o.release, 'release').equals('v1.1.0')
      ..has((o) => o.sources, 'sources').equals('../assets');
  });

  test('--attach-built attaches an output without building', () {
    final options = parseBuildArguments([
      '--release=v1.1.0',
      '--attach-built=out',
    ]);

    check(options).isNotNull()
      ..has((o) => o.mode, 'mode').equals(BuildMode.attachBuilt)
      ..has((o) => o.attachBuilt, 'attachBuilt').equals('out');
  });

  test('--finalize publishes the platforms --require names', () {
    final options = parseBuildArguments([
      '--release=v1.1.0',
      '--finalize',
      '--require=macos-arm64,linux-arm64,windows-x64',
    ]);

    check(options).isNotNull()
      ..has((o) => o.mode, 'mode').equals(BuildMode.finalize)
      ..has((o) => o.require, 'require').isNotNull().deepEquals([
        BuildPlatform.macosArm64,
        BuildPlatform.linuxArm64,
        BuildPlatform.windowsX64,
      ]);
  });

  for (final arguments in [
    ['--release=v1.1.0', '--sources=a', '--attach', '--publish'],
    ['--release=v1.1.0', '--sources=a', '--attach', '--dry-run'],
    ['--release=v1.1.0', '--attach'],
    ['--sources=a', '--attach'],
    ['--release=v1.1.0', '--sources=a', '--attach', '--attach'],
    ['--release=v1.1.0', '--sources=a', '--attach', '--attach-built=o'],
    ['--release=v1.1.0', '--attach-built='],
    ['--attach-built=o'],
    ['--release=v1.1.0', '--attach-built=o', '--sources=a'],
    ['--release=v1.1.0', '--attach-built=o', '--publish'],
    ['--release=v1.1.0', '--attach-built=o', '--dry-run'],
    ['--release=v1.1.0', '--finalize'],
    ['--release=v1.1.0', '--finalize', '--require='],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm6'],
    ['--release=v1.1.0', '--finalize', '--require=linux-x64'],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm64,macos-arm64'],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm64,'],
    ['--finalize', '--require=macos-arm64'],
    ['--release=v1.1.0', '--require=macos-arm64'],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm64', '--publish'],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm64', '--dry-run'],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm64', '--sources=a'],
    ['--release=v1.1.0', '--finalize', '--require=macos-arm64', '--attach'],
  ]) {
    test('refuses ${arguments.join(' ')}', () {
      check(parseBuildArguments(arguments)).isNull();
    });
  }
}
