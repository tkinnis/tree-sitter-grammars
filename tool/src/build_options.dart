/// The command line of `tool/build_tree_sitter_grammars.dart`.
library;

import 'build_platform.dart';

/// What the command does.
enum BuildMode {
  /// Builds `output/`; with `--release`, packs it, and with `--publish`
  /// creates the draft release from it.
  build,

  /// Builds from `--sources` as a release, then attaches the archive to
  /// the draft.
  attach,

  /// Attaches the archive an earlier build left in `--attach-built`'s
  /// directory to the draft, building nothing.
  attachBuilt,

  /// Publishes the draft once the `--require`d platforms' archives are
  /// attached.
  finalize,
}

/// What the command line asks for.
typedef BuildOptions = ({
  BuildMode mode,
  String? release,
  bool dryRun,
  bool publish,
  String? sources,
  String? attachBuilt,
  List<BuildPlatform>? require,
});

/// Reads [args], or returns null when they are not a command the build
/// takes.
///
/// Each flag may be given once. `--dry-run` and `--publish` need
/// `--release` and exclude each other and every attach and finalize flag.
/// `--attach` needs `--release` and `--sources`; `--attach-built` needs
/// `--release` and excludes `--sources`; `--finalize` needs `--release` and
/// `--require`, a comma-separated list of distinct platform ids, and
/// excludes `--sources`; `--require` is for `--finalize` alone.
BuildOptions? parseBuildArguments(List<String> args) {
  String? release;
  String? sources;
  String? attachBuilt;
  String? requireList;
  var dryRun = false;
  var publish = false;
  var attach = false;
  var finalize = false;
  for (final arg in args) {
    if (arg.startsWith('--release=') && release == null) {
      release = arg.substring('--release='.length);
    } else if (arg.startsWith('--sources=') && sources == null) {
      sources = arg.substring('--sources='.length);
    } else if (arg.startsWith('--attach-built=') && attachBuilt == null) {
      attachBuilt = arg.substring('--attach-built='.length);
    } else if (arg.startsWith('--require=') && requireList == null) {
      requireList = arg.substring('--require='.length);
    } else if (arg == '--dry-run' && !dryRun) {
      dryRun = true;
    } else if (arg == '--publish' && !publish) {
      publish = true;
    } else if (arg == '--attach' && !attach) {
      attach = true;
    } else if (arg == '--finalize' && !finalize) {
      finalize = true;
    } else {
      return null;
    }
  }
  if (sources != null && sources.isEmpty) return null;
  if (attachBuilt != null && attachBuilt.isEmpty) return null;
  final modes = [dryRun, publish, attach, finalize, attachBuilt != null];
  final flags = modes.where((flag) => flag).length;
  if (flags > 0 && release == null) return null;
  if (flags > 1) return null;
  if (requireList != null && !finalize) return null;
  if (attach && sources == null) return null;
  if (finalize) {
    if (sources != null) return null;
    final platforms = _platforms(requireList);
    if (platforms == null) return null;
    return (
      mode: BuildMode.finalize,
      release: release,
      dryRun: false,
      publish: false,
      sources: null,
      attachBuilt: null,
      require: platforms,
    );
  }
  if (attachBuilt != null && sources != null) return null;
  return (
    mode: attach
        ? BuildMode.attach
        : attachBuilt != null
        ? BuildMode.attachBuilt
        : BuildMode.build,
    release: release,
    dryRun: dryRun,
    publish: publish,
    sources: sources,
    attachBuilt: attachBuilt,
    require: null,
  );
}

/// The distinct platforms the comma-separated ids [list] name, or null
/// when [list] is absent, empty or names anything else.
List<BuildPlatform>? _platforms(String? list) {
  if (list == null || list.isEmpty) return null;
  final platforms = [for (final id in list.split(',')) BuildPlatform.parse(id)];
  if (platforms.contains(null)) return null;
  final known = platforms.nonNulls.toList();
  return known.toSet().length == known.length ? known : null;
}
