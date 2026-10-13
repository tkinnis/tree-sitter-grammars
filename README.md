# Tree-Sitter Grammars

Pre-built tree-sitter grammar libraries and query files for syntax highlighting.

## Overview

This repository contains:

- **Query files** (`queries/`): tree-sitter query files (`.scm`) for syntax highlighting, code folding, indentation and more, with each language's `config.json`
- **Build tooling** (`tool/`): Dart scripts that build the tree-sitter runtime and every grammar from pinned sources, and pack them into one archive
- **Patches** (`patches/`): fixes to grammar sources, applied to a grammar's tree at its pin before it compiles
- **Tests** (`test/`): tests of the build tooling, run with `dart test`

A local command builds the archive from pinned sources: the tree-sitter runtime **v0.27.0** (commit `6070dbfefd326bd735e5683eb128cc1b57dad0c0`) and each grammar at one upstream commit, with the patches under `patches/` that its entry lists applied. Every library is compiled with `-O3` and tree-sitter's internal assertions on, for the platform the build runs on: a thin binary for **macOS on arm64** with a deployment target of macOS 13.0, a shared object for **Linux on arm64** that needs nothing but glibc, or a DLL for **Windows on arm64** (or **x64**, built by an x64 Dart) that needs nothing but Windows 10 or later. Each release attaches the source of every repository it compiles from, so it can be rebuilt without those repositories.

## Supported Languages

49 compiled grammars, four query-only languages that others inherit (`ecma`, `jsx`, `html_tags`, `php_only`) and plain text, including: Ada, Bash, C, C++, C#, CSS, Dart, Go, Haskell, HTML, Java, JavaScript, JSON, Kotlin, Lua, Markdown, Objective-C, OCaml, Pascal, Perl, PHP, Python, Ruby, Rust, Scala, SQL, Swift, TypeScript, XML, YAML and Zig.

See `tool/grammars.json` for the complete list.

## Repository Structure

```
tree-sitter-grammars/
├── queries/                        # Query files and config.json per language
├── tool/
│   ├── grammars.json               # Each grammar's repository, pinned commit and licence
│   ├── toolchain.json              # The tree-sitter runtime, CLI, macOS target and Linux and Windows CLIs
│   ├── query_provenance.json       # Where each query file came from
│   ├── build_tree_sitter_grammars.dart  # The build
│   ├── pin_grammars.dart           # Sets and checks grammar pins
│   ├── check_query_provenance.dart # Checks query_provenance.json and each query file's header
│   ├── write_notices.dart          # Generates THIRD_PARTY_NOTICES.md
│   ├── validate_manifest.dart      # Checks a built manifest.json
│   ├── check_release.dart          # Checks a built output/ through the runtime it ships
│   ├── parse_input.dart            # Parses and reparses one source, for a crash test
│   ├── parse_compared.dart         # Parses the inputs --against compares with the other archive's grammar
│   ├── bootstrap_language.dart     # Imports a new language's queries from nvim-treesitter
│   └── src/                        # Libraries the tools share
├── patches/<repository>/           # Patches to a grammar's sources, listed in grammars.json
├── test/                           # Tests of the tools
│   ├── crashes/                    # Sources each grammar must parse without ending the process
│   ├── highlights/                 # Sources and what their highlights.scm must draw
│   ├── injections/                 # Sources and what their injections.scm must inject
│   ├── outline/                    # Sources and the outlines their tags.scm must give
│   └── tests/                      # Sources and the groups their tests.scm must put around each test
├── LICENSE                         # This repository's licence (MIT)
├── LICENSES/Apache-2.0.txt         # nvim-treesitter's licence
├── THIRD_PARTY_NOTICES.md          # Every licence the archive carries (generated)
├── CHANGELOG.md
├── pubspec.yaml, pubspec.lock      # The tools' Dart packages, locked
├── tree-sitter/                    # The tree-sitter runtime (submodule)
├── grammars/                       # Git object stores of the grammars (gitignored)
├── .cache/                         # The pinned CLI and nvim-treesitter's objects (gitignored)
├── build/                          # Extracted sources and objects (gitignored)
└── output/                         # The last successful build (gitignored)
```

## Building Locally

### Prerequisites

On macOS:

- Dart SDK 3.11+
- Xcode with the macOS SDK (the build uses its clang, found through `xcrun`)
- macOS on arm64

On Linux:

- Dart SDK 3.11+ on arm64
- clang, whose `clang` is on `PATH`, with GNU ld (binutils), installed by a package dpkg or rpm knows, and glibc's development files for `aarch64-linux-gnu` (on Debian or Ubuntu, `clang`, `binutils` and `libc6-dev`)
- git, gzip and GNU tar in `/usr/bin`

On Windows:

- Dart SDK 3.11+, native to the architecture the build targets: an arm64 Dart builds `windows-arm64`, an x64 Dart `windows-x64`
- LLVM's clang 16 or later, with `clang.exe` and `lld-link.exe` in a directory on `PATH`
- Visual Studio 2022 or its Build Tools with the MSVC build tools for that architecture (`Microsoft.VisualStudio.Component.VC.Tools.ARM64` or `...VC.Tools.x86.x64`), and a Windows 10 or 11 SDK
- Git for Windows, whose `git.exe` is on `PATH`

A build on Windows compiles with LLVM's clang targeting `aarch64-pc-windows-msvc` or `x86_64-pc-windows-msvc`, not MSVC's `cl.exe`: clang takes the same `-O3`, `-std=c11` and defines as the macOS build, so both platforms compile the same code the same way, and it compiles the C11 and GNU extensions grammar scanners use, which `cl.exe` refuses or reads differently. It links against the newest Visual Studio `vswhere` finds with those tools and the newest Windows SDK under the Windows Kits root the registry names, both passed to clang by path, so no `INCLUDE`, `LIB` or developer prompt decides what the libraries link.

The tree-sitter runtime is the `tree-sitter/` submodule at v0.27.0, pinned in `tool/toolchain.json`. Each grammar is pinned to one upstream commit in `tool/grammars.json`. The two grammars that commit no `parser.c` (latex and swift) are generated by the tree-sitter CLI release named in `tool/toolchain.json`, which the build downloads into `.cache/` and checks against its sha256; the files it generates must have the `generatedSha256` the grammar's entry records.

### Build Steps

```bash
git clone --recursive https://github.com/tkinnis/tree-sitter-grammars
cd tree-sitter-grammars
dart pub get
dart run tool/build_tree_sitter_grammars.dart
```

`dart pub get` installs the package versions `pubspec.lock` records. The first build fetches each grammar's pinned commit from its repository and the pinned CLI from tree-sitter's releases, so it needs the network; later builds reuse what `grammars/` and `.cache/` hold.

The build starts from empty `build/` and `output/` directories. For the runtime and every grammar repository it packs a source bundle: the tree `git archive` writes at the pin, run by `/usr/bin/git` (the git of the Xcode `xcrun` selects) with git's user and system configuration shut out, compressed by `/usr/bin/gzip -n -9` into `output/sources/<repository>-<commit>.tar.gz`. It uses `tree-sitter/` and `grammars/<repo>` only as git object stores (a grammar's store is created and fetched as needed; its working tree is never read), unpacks each bundle into `build/src/`, and checks every unpacked file against its committed blob. It then applies the patches a grammar's entry lists to its tree in `build/src/` and checks the patched files against the entry's `patchedSha256` (see [Patching a Grammar's Sources](#patching-a-grammars-sources)); the bundle stays the tree at the pin. What the CLI generates for latex and swift is packed the same way into `output/sources/<grammar>-generated-<commit>.tar.gz`, with fixed modes and times. It compiles the runtime from its `lib/src/lib.c` and each grammar from its `parser.c` and, where it has one, its `scanner.c` with Xcode's clang (`xcrun --find clang`), passing `-O3` explicitly and never defining `NDEBUG`, so tree-sitter's internal assertions stay on. Each compiler invocation sees only `PATH`, `TMPDIR` and `DEVELOPER_DIR`, so a `CFLAGS`, `CPPFLAGS` or `LDFLAGS` in the environment changes nothing. `output/build_info.json` records the runtime, the compiler's path and `--version` line, the SDK, the exact flags for the runtime and for grammars (the flags every grammar compile and every link share, and each grammar's own: the include directory its `parser.c` compiles against, the one its `scanner.c` compiles against, which is its committed `src/` when that holds `tree_sitter/` headers and the generated sources otherwise, and its install name), the versions of the git, gzip and tar that write the bundles and the archive, and the sha256 of every source bundle, beside it the path and sha256 of every patch applied to its tree and the tree's `patchedSha256`; `build/compile_commands.json` records every compiler invocation, and the build fails unless each one passed exactly the recorded flags.

The build writes into `build/out/` and moves it to `output/` only after every check passes, so `output/` exists only after a successful build.

### Building on Windows

A build on Windows checks the same pins, digests, patches, notices and queries, and differs from the macOS build only where the platform does:

- Each library is a DLL: `tree-sitter.dll` and `<language>.dll`, the names `OS.dylibFileName` gives them, beside the query files in `dylibs/<language>/` as on macOS. clang links them with `lld-link`, the Visual C++ runtime statically and the Universal CRT dynamically (`-fms-runtime-lib=static`, `/nodefaultlib:libucrt.lib`, `/defaultlib:ucrt.lib`), so each imports nothing but `KERNEL32.dll` and the `api-ms-win-crt-*` DLLs every Windows 10 and later carries, and every library allocates from the one heap the Universal CRT keeps. `/brepro` links the same objects to the same bytes, and `/noimplib` leaves no import library beside a DLL.
- tree-sitter marks none of its API for export on Windows, so the runtime's link exports every function `api.h` declares, but the three that need its wasm feature, and, as data, the allocator variables `lib/src/alloc.h` marks `TS_PUBLIC` (`ts_current_malloc` to `ts_current_free`), as the macOS runtime exports them, through a module-definition file written from those headers into `build/tree-sitter.def`. Memory the runtime hands a caller to free, such as `ts_tree_get_changed_ranges`'s array, is freed through `ts_current_free`, or the Universal CRT's `free`, never `package:ffi`'s `malloc.free`, which on Windows is `CoTaskMemFree`. A grammar's `parser.c` marks its `tree_sitter_<language>` for export itself.
- The library check reads each DLL's PE headers in Dart (`tool/src/pe.dart`): the machine of the platform, a DLL whose export table carries its own file name, no import beyond `KERNEL32.dll` and the Universal CRT, no delay-loaded DLL, and the expected exports.
- Every compiler invocation sees only `PATH` (the system's own directories), `SystemRoot`, `TEMP` and `TMP`.
- Windows has no git, tar, gzip or shasum at a fixed path: the bundles are written by the first `git.exe` on `PATH`, resolved to its absolute path; they and the archive are compressed by `dart:io`'s zlib at level 9 and the archive is written by `tool/src/tar.dart`, with the owners, modes and times the macOS archive has; digests are computed with `package:crypto`. `build_info.json` records each. NTFS keeps no execute bit, so the git mode of an unpacked file is the one its bundle's tar header gave it, and a bundle holding a symbolic link is refused.
- The CLI that generates latex and swift is the release asset `tool/toolchain.json` pins for the architecture under `windows`; what it generates must have the same `generatedSha256` as on macOS.
- The archive carries `THIRD_PARTY_NOTICES.md` with each library named as Windows names it; the committed file, which names them as macOS does, must still be what the pinned sources produce.
- `build_info.json` records the platform (`windows-arm64` or `windows-x64`), LLVM's clang, the MSVC tools and the Windows SDK, each with its path, in place of the deployment target, Xcode's clang and the macOS SDK.

### Building on Linux

A build on Linux checks the same pins, digests, patches, notices and queries, and differs from the macOS build only where the platform does:

- Each library is a shared object: `libtree-sitter.so` and `lib<language>.so`, the names `OS.dylibFileName` gives them, beside the query files in `dylibs/<language>/` as on macOS. The first `clang` on `PATH` compiles them for `aarch64-linux-gnu` with the macOS build's `-O3`, `-std=c11`, `-fPIC` and, for the runtime, `-fvisibility=hidden`, `-D_POSIX_C_SOURCE=200112L`, `-D_DEFAULT_SOURCE` and `-D_BSD_SOURCE`, with neither an SDK nor `_DARWIN_C_SOURCE`, against the system's headers and C library. Each is linked `-shared` by GNU ld, which `-fuse-ld=bfd` names whatever linker clang was configured to choose, with its file name as its soname (`-Wl,-soname,lib<language>.so`), as macOS gives each its `@rpath` install name, and with `-Wl,-z,defs`, so a symbol nothing defines fails the link rather than the first load.
- The library check reads each shared object's ELF headers in Dart (`tool/src/elf.dart`): a 64-bit `ET_DYN` for `EM_AARCH64`, a soname that is its own file name, no `DT_NEEDED` but `libc.so.6`, no text relocations, and the expected exports; the runtime must export every `api.h` function but the three that need the wasm feature, and the allocator variables `lib/src/alloc.h` marks `TS_PUBLIC`.
- Every compiler invocation sees only `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin`) and `TMPDIR`. clang itself is the first on your `PATH`, so an LLVM you install elsewhere can compile, but the linker and C library it uses it finds beside itself or on that `PATH`, not yours; the build asks it for both in that same environment, the C library with `-print-file-name=libc.so.6` and the linker as the program `clang -###` would run for a grammar's link of an empty object, which is the one a real link runs (clang looks for `aarch64-linux-gnu-ld.bfd` before `ld.bfd`), and `build_info.json` records each answer.
- The bundles are written by `/usr/bin/git` and compressed by `/usr/bin/gzip -n -9`, and the archive is packed by GNU tar (`/usr/bin/tar`) as ustar with the same layout, modes, owners and times as the macOS archive (files only, owned by root:wheel), though not the same header bytes, which differ between GNU tar and bsdtar in fields such as the device numbers; `build_info.json` records each tool's version. Digests are computed with `package:crypto`, as on Windows, so a build needs no `shasum`, which a minimal image lacks.
- The CLI that generates latex and swift is the release asset `tool/toolchain.json` pins for the architecture under `linux`; what it generates must have the same `generatedSha256` as on macOS.
- The archive carries `THIRD_PARTY_NOTICES.md` with each library named as Linux names it.
- `build_info.json` records the platform (`linux-arm64`) and, as `glibcRequirement`, the glibc the libraries need: the highest `GLIBC_` version that `libtree-sitter.so` or any grammar's shared object names in its version-needed section (`.gnu.version_r`), which `tool/src/elf.dart` reads and compares number by number, for example `"2.17"`; a version that names a feature rather than a release counts as the glibc that first defines it (`GLIBC_ABI_DT_RELR`, which a library linked with packed relative relocations needs, as 2.36), and the build refuses a library naming a `GLIBC_` version of no release it knows, other than `GLIBC_PRIVATE`. The release notes say the archive runs on Linux with that glibc and later, and `tool/check_release.dart` reads the libraries again and refuses a record that differs. It records too clang and its path; GNU ld, as the first line of its `--version` (`toolchain.linker`), with the package that installed it and its version with the distribution's revision, which `--version` leaves out, as dpkg or else rpm names it (`toolchain.linkerPackage`, for example `binutils-aarch64-linux-gnu 2.46-3ubuntu2`), its path as clang names it, normalised (`toolchain.linkerPath`, which must name the file clang runs), and that file with every symbolic link resolved, the path the package database is asked by (`toolchain.linkerResolvedPath`, for example `/usr/bin/aarch64-linux-gnu-ld.bfd` for `/usr/bin/ld.bfd`), since another binutils, even one patched by the distribution alone, links the same objects to other bytes; and the build host's glibc they link against, the release the banner of that `libc.so.6` names (`toolchain.hostLibc`, for example `glibc 2.43`), the whole banner, which names the distribution's build of it (`toolchain.hostLibcBanner`, for example `GNU C Library (Ubuntu GLIBC 2.43-2ubuntu2.4) stable release version 2.43`), and its path (`toolchain.hostLibcPath`), the release and the banner both read from the one file clang links against; all in place of the deployment target, Xcode's clang and the macOS SDK. The host's glibc may be later than the one the libraries need.

`tool/check_release.dart` checks only an archive built for the platform it runs on, whose libraries are the only ones it can load. A scanner's failed assertion ends a process on Windows with `abort`, which the Universal CRT turns into a fail-fast (`STATUS_STACK_BUFFER_OVERRUN`) or, in a process with a window, a message box first.

### Checking a Build

The build's last check is `tool/check_release.dart`, which loads the build through the runtime it ships, with `dart:ffi`, and fails unless every source bundle has its recorded sha256 and pinned commit, `build_info.json` records beside each bundle exactly the patches `tool/grammars.json` lists for it, in order, with the sha256 of each committed patch, every bundle of generated sources its recorded sha256, the runtime exports every `api.h` function (apart from the three that need its wasm feature), `manifest.json` holds exactly the entries `tool/grammars.json` plans, every library is a thin arm64 binary with `minos` 13.0 and an `@rpath` install name, `build_info.json` records the language versions the runtime's `api.h` defines and `ts_parser_set_language` accepts every grammar at an ABI between them (13 to 15 at v0.27.0), every query file compiles once its `; inherits:` line is composed as the editor composes it, every language such a line names holds a file of the same type (tsx's `locals.scm` naming `jsx` apart, since jsx has no locals), every query-only file is inherited by one of those, every composition reads as the patterns `ts_query_new` counts in it, every injection pattern captures `@injection.content` and names a language, by an `@injection.language` capture or a `#set! injection.language` directive, in every grammar but those `injectionsNamingNoLanguage` in `tool/src/release_check.dart` lists (each of which holds at least one that names none), every outline test under `test/outline/`, test-structure test under `test/tests/`, injection test under `test/injections/`, highlight test under `test/highlights/` and crash test under `test/crashes/` passes (see [Tests](#tests)), and `THIRD_PARTY_NOTICES.md` is the committed text. Run it on its own, or compare a build with an earlier release's extracted archive:

```bash
dart run tool/check_release.dart                      # checks output/
dart run tool/check_release.dart --against=<archive>  # also compares grammars
```

`--against` parses every example of each grammar's test corpus and every highlight test input from the pinned sources with both archives' grammars under this runtime (for a grammar pinned on a deploy branch, the tests of its `sourceCommit`, read from its object store under `grammars/`; tsx, which is TypeScript with JSX, parses TypeScript's and JavaScript's inputs as well as the one example TypeScript's corpus names it in), and prints each difference in the tree (anonymous nodes included) and in the captures of every query file both archives carry. A match counts only when its pattern's text predicates hold (`#eq?`, `#match?` and `#any-of?`, with their `not-` and `any-` forms, evaluated as tree-sitter documents them; a `#match?` pattern is read as a Dart regular expression), and its ancestry predicates, `#has-ancestor?` and `#has-parent?` with their `not-` forms, read off the tree as the editor reads them: a node of a type the predicate names sits anywhere above the capture's node, or is its parent. Each capture carries its pattern's other predicates and directives, `#set!` among them, as text, so a changed regular expression, `#set!` value or other directive shows as a difference wherever the inputs reach it. It lists every grammar it had no inputs for, and fails when the other archive's manifest pins one of those at another commit.

The other archive's grammars parse in processes of their own, one per grammar and four at a time, running `tool/parse_compared.dart`, compiled to kernel once per run, under this runtime, since an earlier release can hold a scanner that aborts on input a later pin's tests hold, which would end any process that loaded it. Such an input, or one a process parses for longer than 60 seconds, is printed as one the old release crashes on, with the signal and what the process wrote to stderr; a new process parses the inputs after it, and the summary counts the inputs each grammar's process ended on, which are not compared. Each grammar is compared as soon as its processes are done, while those of the grammars after it run. v1.2.2's Ruby scanner aborts on the long heredoc word Ruby's corpus holds at its current pin:

```
ruby: the old release crashes on tree-sitter-ruby/test/corpus/literals.txt: heredoc with long identifier (>255 chars)
  the parse ended the process with SIGABRT: Assertion failed: (size == length), function deserialize, file scanner.c, line 160.
```

Each process writes its parses to a results file of its own, leaving stdout to the grammar's scanner, so whatever a scanner prints there is set aside; a line in the results file that is not a parse is printed as the process failing on that input, and a new process parses the inputs after it. The first line a process writes names the query files it compiled, and the comparison fails when those differ from the ones the check compiles itself from the same grammar's files, since the captures of a file are compared only when both sides compiled it. A process of the other archive's grammar that fails to start, or ends before it is ready to parse, having failed to load the library or read its request, fails the comparison too.

### Pinning Grammars

```bash
dart run tool/pin_grammars.dart --check                  # every url entry has a 40-hex commit, a filesSha256 and a license
dart run tool/pin_grammars.dart --set tree-sitter-c=<sha>  # move one pin; the commit must be on a branch of origin
dart run tool/pin_grammars.dart --set tree-sitter-perl=<deploy sha> --source-commit=<source sha>  # pin a deploy branch
dart run tool/pin_grammars.dart --from-checkouts          # move each pin forward to its grammars/<repo> HEAD
dart run tool/pin_grammars.dart --record-files           # record filesSha256 afresh for every pin, the runtime's included
```

Three pins are not their checkout's `HEAD`, on purpose: perl and sql are pinned to their deploy branches (`release` and `gh-pages`), which commit the generated `parser.c`, with `sourceCommit` naming the commit each was deployed from, and swift is pinned ahead of its checkout, to the commit whose scanner allocates at least one byte. A deploy pin moves only with `--set <repo>=<deploy commit> --source-commit=<source commit>`; both commits must be on a branch of origin. `--from-checkouts` moves a pin only forward, to a `HEAD` that contains it, and keeps each of these three, naming the `--set` that moves it; a generated grammar it moves gets its `generatedSha256` afresh. Every mode but `--check` writes `tool/grammars.json` only when the result passes `--check`, and writes nothing otherwise.

Every pin records, beside its commit, the `filesSha256` of the files its tree holds: the sha256 of one `<mode> <blob id>\t<path>` record per file, each ending in a NUL, sorted by path, with submodule entries left out (a source bundle carries no files for them). `--set` and `--from-checkouts` record it from the object store; the runtime's is in `tool/toolchain.json`. The build checks every tree it compiles against it, so a pin and its files cannot drift apart unseen. A generated grammar's entry also records `generatedSha256`, the same digest of the files the pinned CLI generates for the pin at the runtime's language ABI; `--set` and `--record-files` generate them to record it, and the build requires it of what it generates or takes from a release. An entry that lists `patches` also records `patchedSha256`, the same digest of its files once the patches are applied; every mode that records `filesSha256` applies them to the tree at the pin to record it, and refuses a pin they do not apply to.

### Patching a Grammar's Sources

A fix to a grammar's C sources that no upstream commit carries is a patch in this repository, `patches/<repository>/<name>.patch`, listed under `patches` in the grammar's entry, in the order they apply:

```json
{
  "url": "https://github.com/tree-sitter-grammars/tree-sitter-yaml",
  "commit": "7708026449bed86239b1cd5bce6e3c34dbca6415",
  "filesSha256": "9684d1aebce4191b551575896720e6693a3306ae3286a308e3e117041398f2e2",
  "license": "MIT",
  "patches": [
    "patches/tree-sitter-yaml/serialize-indents-that-fit.patch"
  ],
  "patchedSha256": "8c38bae67fec1fd4e594f4ddd61145c135726e00c6890a953996ed11665b45f9"
}
```

A patch is what `git diff --full-index` writes in a checkout of the grammar at its pin, with paths relative to the repository's root, after a few lines that say what it changes, why, and the commit it applies to. The build applies each with `git apply` against the grammar's tree alone, so its context must match exactly and no path may lead out of the tree, and the patched files must have the `patchedSha256` the entry records, which `--record-files` writes:

```bash
dart run tool/pin_grammars.dart --record-files
dart run tool/write_notices.dart
```

`THIRD_PARTY_NOTICES.md` names every patch and the files it modifies under its grammar, and the source bundle a release attaches stays the upstream tree at the pin, so a release is rebuilt from its bundles and the patches its tag carries. A patch belongs here only until a commit upstream carries the fix: pin that commit and remove the patch.

The scanners of markdown, yaml, kotlin, python and perl are patched so that the state each one serializes fits the 1024 bytes tree-sitter gives it. Unpatched, deep enough nesting (a line of 255 `>` in Markdown) writes past that buffer, which the runtime, with its assertions on, stops by aborting the whole process. ruby needs no patch for the same fault in its heredoc state: it is pinned at the upstream commit that fixes it.

### Moving the Runtime

The runtime moves only to a tagged tree-sitter release. Check the submodule out at the tag's commit and stage it:

```bash
git -C tree-sitter fetch --tags
git -C tree-sitter checkout <commit of the tag>
git add tree-sitter
```

In `tool/toolchain.json`, set `treeSitter`'s `tag` and `commit`, `treeSitterCli`'s `version` and `sha256` to that release's `tree-sitter-macos-arm64.gz`, each `linux.<arch>.cliSha256` to that release's `tree-sitter-linux-<arch>.gz`, and each `windows.<arch>.cliSha256` to that release's `tree-sitter-windows-<arch>.gz`. Then record the digests afresh, regenerate the notices, build, and compare the build with the last release's extracted archive:

```bash
dart run tool/pin_grammars.dart --record-files
dart run tool/write_notices.dart
dart run tool/build_tree_sitter_grammars.dart
dart run tool/check_release.dart --against=<archive>
```

The build refuses a submodule checked out at any commit but the one `tool/toolchain.json` names, and a runtime whose Makefile `VERSION` is not that tag's version. The language ABIs follow the runtime's `api.h`: latex and swift are generated at its `TREE_SITTER_LANGUAGE_VERSION`, `build_info.json` records it and `TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION`, and `tool/validate_manifest.dart` and `tool/check_release.dart` accept a grammar at any ABI between the two, so a runtime at a new language version needs no other change. `--against` prints every tree and query-result difference the move makes.

### Tests

```bash
dart test
```

`dart test` tests the tools. The query files are tested through a build: `tool/check_release.dart` runs every outline test under `test/outline/<grammar>/`, a source file beside a `<source>.outline` file. The source must parse with no error or missing node, and the grammar's composed `tags.scm` must find in it the definitions the `.outline` file lists, one per line in the order they start (the wider of two that start together first): the kind after `definition.`, a space, and the name after the names of the definitions whose range holds it, joined by `.`, which is how the editor nests its outline. A C# test's line spells its declaring scope:

```
module Inventory
class Inventory.StockTests
method Inventory.StockTests.CountsWhatWasReceived
```

A file-scoped namespace (`namespace Contoso.Ledger.Tests;`) holds the declarations after it, which the grammar parses as its siblings, so C#'s `tags.scm` defines it over the whole compilation unit, and they nest under it. A struct and a record are defined too, so a method nests under the one that declares it; a record struct is defined as a class, since the grammar marks it only by its `struct` keyword.

A Java package declaration (`package com.example.ledger;`) and a Kotlin package header (`package com.example.ledger`) hold the declarations after them the same way, so Java's and Kotlin's `tags.scm` define the package over the whole program or source file, as a `package`, and a class and its methods nest under it — `method com.example.ledger.LedgerTest.balancesAfterPosting`. A file declaring no package outlines its classes at the top.

A Swift extension declares members of the type it names, so Swift's `tags.scm` defines it as a `class` over its body, named by the type as the extension writes it, and its members nest under it as they do under the type's own declaration — `function OuterSuite.alsoWorks` — whatever file declares the type. A type reached by a path or extended at arguments keeps the spelling: `class Outer.Inner`, `class Array<Int>`.

It runs every test-structure test under `test/tests/<grammar>/` the same way, a source beside a `<source>.tests` file that lists what the grammar's composed `tests.scm` says encloses each test in it, as the editor reads it to name the `describe` blocks a test runner selects a test by: one line per test in the order they start, its one-based line, a space, and either the names of the groups around it, outermost first, as a JSON array, or `withheld` and why they cannot be read. Dart's `tests.scm` names `test` and `testWidgets` calls and `group` calls whose function holds what they register; a group's name is the text between the quotes that open and close it, `@group.name.open` and `@group.name.close`, since a Dart string's text is not a node of its own, and a function's body other than `main`'s is opaque. JavaScript's, TypeScript's and TSX's `tests.scm` share ecma's, which names the calls jest, bun, vitest and mocha register by: a test is a call of `test` or `it` (`fit`, `xit` and `xtest` too, under modifiers such as `.only`, `.each` and `.skipIf`), and a group a call of `describe`, `context`, `suite`, `fdescribe` or `xdescribe` whose function's body holds what it registers. A test is withheld where another starts on its line (`sharedLine`), where the file binds a group function's name otherwise than by importing it from `@jest/globals`, `bun:test`, `vitest`, `node:test` or `mocha` (`rebinding`), and otherwise for the innermost level around it that is not a group named in plain text — a string or a template literal holding no escape and no substitution: a function's body that is no group's (`opaque`), a group named by anything else (`unnamed`), or a group per row of a table, `describe.each` or `describe.for` (`table`):

```
6 ["outer alpha"]
9 ["outer alpha","inner, a template with no substitution"]
22 withheld table
```

It runs every injection test under `test/injections/<grammar>/` the same way, a source beside a `<source>.injections` file that lists what the grammar's composed `injections.scm` injects in it as the editor injects it, one line per injection in the order they start (the wider of two that start together first): the language, ` combined` when the pattern sets `injection.combined`, a space, and the whole text of the node the pattern captures as `@injection.content`, JSON-encoded. The editor reads no `#offset!` directive, so the text is the node's own:

```
comment "// Every register's offset."
c "(0x0004u)"
```

It runs every highlight test under `test/highlights/<grammar>/` the same way, a source beside a `<source>.highlights` file that lists what the grammar's composed `highlights.scm` draws in it, one line per span a capture covers, in the order they start (the wider of two that start together first): the capture drawn there, a space, and the span's text, JSON-encoded. Of the captures over one span, the latest pattern's is drawn, the convention the queries are written to (see `queries/README.md`), and `@none`, `@spell`, `@nospell` and a capture whose name starts with `_` name no colour and are left out. Each test holds a few lines in which two patterns capture the same node, so a pattern moved to the wrong side of another changes a line. `--against` compares the captures each query makes, which moving a pattern leaves as they were, so these tests are where a change of order shows:

```
string.special.key "\"name\""
string "\"finch\""
```

It runs every crash test under `test/crashes/<grammar>/`: each source there is parsed with the grammar, then parsed again after an edit that appends a newline, reusing the tree as the editor does after a keystroke, in a process of its own running `tool/parse_input.dart`. The process must exit 0 within 60 seconds. A crash test holds input deep enough to overrun a scanner's state, such as a line of a thousand `>` in Markdown, so a scanner that aborts or crashes on it fails the test by name, with the signal and what the process wrote, and the check goes on to the rest. The parse may hold errors; the test asks only that it ends.

## Using Pre-built Binaries

Download `grammars-macos-arm64.tar.gz` from [GitHub Releases](../../releases). A build on Linux packs `grammars-linux-arm64.tar.gz` with the same layout, holding `libtree-sitter.so` in place of `libtree-sitter.dylib` and `dylibs/<language>/lib<language>.so` in place of `lib<language>.dylib`. A build on Windows packs `grammars-windows-arm64.tar.gz` or `grammars-windows-x64.tar.gz` with the same layout, holding `tree-sitter.dll` in place of `libtree-sitter.dylib` and `dylibs/<language>/<language>.dll` in place of `lib<language>.dylib`. The `manifest.json` of each is the same.

### Archive Contents

```
grammars-macos-arm64.tar.gz
├── libtree-sitter.dylib       # The tree-sitter runtime
├── manifest.json              # Every language, its library and its pinned source
├── build_info.json            # The runtime, compiler, flags, packing tools and source bundles the build used
├── THIRD_PARTY_NOTICES.md     # Every licence of the runtime, the grammars and the queries
├── dylibs/
│   ├── c/
│   │   ├── libc.dylib
│   │   ├── config.json        # Language configuration
│   │   └── *.scm              # Query files
│   └── .../
└── queries/                   # Query-only languages: ecma, html_tags, jsx, php_only
    └── <lang>/
        ├── config.json
        └── *.scm
```

Every library's install name is `@rpath/<file name>`.

## Adding a New Language

1. Import the language's queries from nvim-treesitter. The language name is the grammar's name, which also names its `queries/` directory and its library:

```bash
dart run tool/bootstrap_language.dart --language=mylang [--commit=<sha>]
```

It fetches nvim-treesitter's `HEAD` and branches, with their history, into `.cache/nvim-treesitter` (about 10 MB), with git's user and system configuration shut out. It reads the queries at `HEAD`, or at the 40-hex `--commit`, which one of nvim-treesitter's branches must contain, from `runtime/queries/<name>/` (or `queries/<name>/` in a commit from before the queries moved), and writes the highlights, folds, injections, locals and indents queries that commit has for the language into `queries/mylang/`. Each file carries the header naming its nvim-treesitter path and commit, and gets an entry in `tool/query_provenance.json` recording the same. It also writes a `tags.scm` placeholder and a `config.json` skeleton where the language has none. It reads and checks everything before writing, so a refused run writes nothing under `queries/` or `tool/`, and it refuses to write over a path that changed while it ran or that is not a file. It refuses a language whose other spelling, one nvim-treesitter names the same (`c_sharp` for `c-sharp`), has a `queries/` directory. It refuses a language that already has a `queries/` directory unless given `--force`, which replaces only what a bootstrap wrote there (an import of the same language and query type whose text is still its upstream file under its header, or the placeholder `tags.scm`), removes such an import of a query type the commit no longer has, and refuses a file that holds other work. It prints every file and provenance entry before writing them; `--dry-run` fetches and prints, and writes none of them. `queries/README.md` lists the bootstrap's limits; among them, run one bootstrap at a time.

2. Edit `queries/mylang/config.json` and adapt the queries. For every file you change, set `"changed": true` in its `tool/query_provenance.json` entry, then rewrite the headers:

```bash
dart run tool/check_query_provenance.dart --write-headers
```

3. Add the grammar's repository and licence to `tool/grammars.json`, then pin it:

```json
{
  "url": "https://github.com/user/tree-sitter-mylang",
  "license": "MIT"
}
```

```bash
dart run tool/pin_grammars.dart --set tree-sitter-mylang=<sha>
```

The entry builds every grammar its repository's `tree-sitter.json` lists, with the name, scope and file types that file gives; `"grammars": [...]` chooses among them. A repository with no `tree-sitter.json` names its one grammar with `"name"` (and `"path"` when the grammar is not at its root). `displayName`, `scope` and `file-types` (without the dot) on the entry take precedence over `tree-sitter.json`, and `filenames` lists whole file names the grammar opens. A grammar that commits no `src/parser.c` also takes `"generate": true`.

4. Regenerate the notices and build. The build ends with `tool/check_release.dart`, which compiles every query file through the runtime:

```bash
dart run tool/write_notices.dart
dart run tool/build_tree_sitter_grammars.dart
```

## Query File Types

| File | Purpose |
|------|---------|
| `highlights.scm` | Syntax highlighting patterns |
| `folds.scm` | Code folding regions |
| `indents.scm` | Auto-indentation rules |
| `injections.scm` | Language injection (e.g., JS in HTML) |
| `locals.scm` | Scope and variable tracking |
| `tags.scm` | Symbol extraction for navigation |
| `textobjects.scm` | Semantic text objects |
| `config.json` | Language configuration (see below) |

### config.json Schema

Each language has a `config.json` with metadata and editor settings:

```json
{
  "displayName": "Ruby",
  "symbol": "ruby",
  "scope": "source.ruby",
  "extensions": [".rb"],
  "comments": {
    "line": "#",
    "block": ["=begin", "=end"]
  },
  "brackets": [
    {"open": "{", "close": "}", "autoClose": true, "newline": true},
    {"open": "(", "close": ")", "autoClose": true, "newline": false}
  ],
  "indentation": {
    "blockOpeners": ["{", "(", "["],
    "keywordOpeners": ["do", "then", "begin"],
    "lineStartKeywords": ["def", "class", "module", "if"],
    "dedentPairs": [
      {"open": "def", "close": "end"},
      {"open": "class", "close": "end"}
    ]
  },
  "queries": {
    "highlights": true,
    "folds": true,
    "indents": true
  }
}
```

| Field | Description |
|-------|-------------|
| `displayName` | Human-readable name |
| `symbol` | Entry point symbol name in native library |
| `scope` | TextMate scope for theme matching |
| `extensions` | File extensions (including dot) |
| `comments` | Comment delimiters for toggle/insertion |
| `brackets` | Auto-close and smart bracket settings |
| `indentation` | Heuristic indent settings for real-time typing |
| `queries` | Which query files are available |

## Creating Releases

A release is a draft until every platform's archive is attached to it, because a published GitHub release is immutable and never gains an asset. A Mac builds, packs and creates the draft, Linux and Windows add their archives to it (step 4), and the Mac publishes it (step 5). Every command that changes GitHub needs the GitHub CLI, signed in with write access to the repository.

1. Tag a clean `HEAD` with an annotated tag:

```bash
git tag -a v1.1.0 -m v1.1.0
```

2. Build and pack it. The build refuses a dirty working tree, a runtime submodule other than the one `tool/toolchain.json` pins, and a `HEAD` that the annotated tag `v1.1.0` does not name:

```bash
dart run tool/build_tree_sitter_grammars.dart --release=v1.1.0
```

A release reads this repository's own files (`tool/grammars.json`, `tool/toolchain.json`, `tool/query_provenance.json`, `queries/`, the licences and `THIRD_PARTY_NOTICES.md`) from the tree of the commit it builds, extracted into `build/repository` and checked against the committed blobs, never from the working tree, so an edit made while it runs cannot reach the archive. It packs nothing unless, once every check has passed, `HEAD` is still that commit and the working tree still clean, and `tool/check_release.dart` refuses a `build_info.json` that records a release built from a dirty working tree.

It writes `output/grammars-macos-arm64.tar.gz` and its sha256 in `output/grammars-macos-arm64.tar.gz.sha256`. The archive holds files only, in sorted order, as ustar with no macOS metadata, extended attributes, ACLs or file flags; every file is owned by root:wheel, has mode 0644 (0755 for a dylib) and carries the time of the commit built, and `gzip -n -9` compresses it, so the same build packs to the same bytes. `--dry-run` skips only the tag requirement and packs the same bytes into `output/grammars-macos-arm64.dry-run.tar.gz`, a name no release asset has. On Linux the same command packs `output/grammars-linux-arm64.tar.gz`, and on Windows `output/grammars-windows-<arch>.tar.gz` (or `.dry-run.tar.gz`), the same way, 0755 going to each shared object or DLL.

The archive's sha256 identifies a build of one commit: `build_info.json`, which the archive carries, names the commit, and every file carries its time. A dry run of the commit a tag will name packs the tag's bytes; a dry run of any other commit, even one that changes nothing else in the archive, packs another sha256. Compare a digest only with a build of the same commit.

It also writes the release notes into `output/release-notes.md`: the runtime, the archive's sha256, every repository's pinned commit with its source bundle and that bundle's sha256, and each bundle of generated sources with its sha256.

3. Push the tag, then build again with `--publish`, which creates a draft:

```bash
git push origin v1.1.0
dart run tool/build_tree_sitter_grammars.dart --release=v1.1.0 --publish
```

`--publish` runs on macOS only, since it creates the draft with the source bundles the macOS build packed. It first lists the repository's releases, every page of them, and refuses when any release, draft or published, carries the tag. It resolves the tag on GitHub and refuses unless it is the annotated tag object the build checked locally and names the commit that was built, so a tag re-created or moved after the push never carries assets built from another commit. It then creates the draft (`gh release create --draft --verify-tag --target <the built commit>`) with those notes, attaching the archive, its `.sha256`, `build_info.json`, every source bundle and every bundle of generated sources, resolves the tag again, and reads the draft back by its id, failing unless the tag still names the built commit and GitHub reports each asset's sha256 digest as the local one.

4. On Linux and on Windows, attach the platform's archive and its `.sha256` to the draft (on Linux, `grammars-linux-arm64.tar.gz`). Download the draft's assets, check out the tag, then build from them and attach:

```bash
gh release download v1.1.0 --repo tkinnis/tree-sitter-grammars --dir ../v1.1.0-assets
dart run tool/build_tree_sitter_grammars.dart --release=v1.1.0 --sources=../v1.1.0-assets --attach
```

`--attach` runs on Linux and Windows only, and cannot be combined with `--publish` or `--dry-run`. Before it compiles anything, it requires the `build_info.json` in `--sources` to name the release `v1.1.0` and, as `repository.commit`, the commit the tag names. After the build packs, it resolves the tag on GitHub as `--publish` does, then finds the draft by listing the releases and refuses unless there is exactly one release of the tag, it is a draft, GitHub does not report it immutable, and its target is the built commit itself, not a branch. It requires the `.sha256` to be exactly the archive's sha256 in lowercase hex, two spaces, the archive's name and one newline, the `build_info.json` inside the archive to name the release, the commit and the platform, the bundle sha256s in that file to be those of the draft's own `build_info.json`, and the output directory's path to hold no `#`, which `gh release upload` reads as the start of an asset label. It uploads with `gh release upload`, never with `--clobber`, resolves the tag again, and reads the draft back, waiting a few seconds for GitHub to compute a new asset's digest: GitHub must report both new assets complete with the local sha256 as their digest and every asset that was there before unchanged. The archives and `.sha256` files of the other platforms may appear meanwhile, since the platforms attach in parallel; any other new asset is refused.

An attach is safe to run again. When the draft already holds both of this platform's assets, complete and with the local sha256 as their digest, it uploads nothing and reports success. When it holds either asset in any other condition, such as a partial upload, an unfinished asset or another digest, it refuses and names the command that removes it, for example `gh release delete-asset v1.1.0 grammars-linux-arm64.tar.gz --repo tkinnis/tree-sitter-grammars`; run it for each asset named and attach again.

A CI runner attaches an archive it built with no compile of its own: `--attach-built=<output dir>` runs the same checks and the same upload on an `output/` built earlier, with the tag checked out and `--release` naming it. The attach job's token needs `contents: write` to see the draft, since a token with read access is not guaranteed to. The owner dispatches the `archives.yml` workflow with the release tag and the platform (`linux-arm64`) to have a Linux runner build its archive and attach it this way. The workflow validates the tag as `vX.Y.Z` before anything else, checks the tag out without persisting credentials and fetches its annotated tag object, installs clang 18 and checks that the runner's glibc is 2.39, builds from the draft's downloaded assets, checks that `glibcRequirement` is no later than 2.39, attests the archive, and attaches it with `--attach-built`. Every action is pinned by a commit SHA, no job holds a permission it does not use, and `test/archives_workflow_test.dart` checks all three.

A build on Windows that packs its own source bundles compresses them with `dart:io`'s zlib rather than macOS's `/usr/bin/gzip -n -9`, so their sha256s, which its `build_info.json` records and its archive carries, are not those of the bundles the draft attaches. With `--sources` it copies the draft's bundles byte for byte into `output/sources/` and records their sha256s, so the Windows archive's `build_info.json` names assets the draft has. A build on Linux compresses its own bundles with its own `/usr/bin/gzip`, whose bytes need not be macOS's, and is built from the draft's assets for the same reason.

5. On the Mac, with the tag checked out, publish the draft once every platform's archive is attached:

```bash
dart run tool/build_tree_sitter_grammars.dart --release=v1.1.0 --finalize --require=macos-arm64,linux-arm64,windows-arm64,windows-x64
```

`--require` and `--allow-missing` together name every platform the repository builds (`macos-arm64`, `linux-arm64`, `windows-arm64`, `windows-x64`), each once. A release with no archive for a platform names it in `--allow-missing`, for example `--require=macos-arm64,linux-arm64 --allow-missing=windows-arm64,windows-x64`, and the release notes list it as "not in this release".

`--finalize` first requires immutable releases to be enabled on the repository, so a release it publishes can never change. It resolves the tag on GitHub and requires the release to be a draft targeting the built commit. It requires the draft's `build_info.json` to name the release and the commit and to record at least one source bundle and one bundle of generated sources, each with a file name and a sha256. It requires the draft to hold the archive and the `.sha256` of every required platform, `build_info.json` and the bundles it records, all complete, and no other asset. An asset of any other name, such as a stray upload or the archive of a platform in `--allow-missing`, is refused, and the message names the command that removes it (`gh release delete-asset v1.1.0 <name> --repo tkinnis/tree-sitter-grammars`). It requires each `.sha256` to be exactly the lowercase sha256, two spaces, the archive's name and one newline, GitHub's digest of each archive to be that sha256, of each `.sha256` to be that of its own content, and of each bundle to be the one `build_info.json` records. It downloads every required archive, requires the bytes to have that sha256, and requires the archive's own `build_info.json` to name the release, the commit and its platform and to record the same bundle sha256s as the draft's, so an archive uploaded by hand from another tag or commit is refused. It reads the glibc a Linux archive needs from that file.

Just before it publishes, it resolves the tag again and reads the draft again, and requires it to be as it was checked: still a draft with the same target and the same assets, each the same upload (by id) with the same digest. It then appends a table of the archives (platform, sha256 and, for Linux, the glibc) to the release notes and publishes the draft in the same request (`gh api -X PATCH`, `draft=false`), resolves the tag a third time, and reads the release back: it must be reported immutable, with the assets it had and their digests. It then prints the sha256 of each archive as a JSON object keyed by platform id, the `sha256` map of finch's `hook/grammars_config.json`.

A check that fails before the publication changes nothing, and the draft can be repaired and finalized again. A failure after the publication cannot be repaired: the release is immutable, so the tag is burned. Do not pin the digests it printed or that the release holds in `hook/grammars_config.json`, and cut the next version; the error says so.

### Rebuilding a Release from Its Source Bundles

A release carries the source of every repository it compiles from, at the commit it pins, so it can be rebuilt after an upstream rewrites or deletes that commit. Download every asset of the release into one directory outside `build/` and `output/`, check out the release's tag, and point the build at that directory:

```bash
gh release download v1.1.0 --repo tkinnis/tree-sitter-grammars --dir ../v1.1.0-assets
git checkout v1.1.0
dart run tool/build_tree_sitter_grammars.dart --release=v1.1.0 --sources=../v1.1.0-assets
```

With `--sources`, the build reads no git object store and needs neither `grammars/` nor the `tree-sitter` submodule. The `build_info.json` in that directory must record the commit the build reads (its `repository.commit`) and, with `--release`, the release it names (its `release`), so the assets of another release, even one with the same pins, are refused rather than recorded as this release's bundles. Without `--release`, a release's assets rebuild at the commit that release tags. The patches a grammar's entry lists are read from the checked-out tag and applied to its unpacked bundle, and the patched files must have the `patchedSha256` the tag records. Each bundle must have the sha256 the release's `build_info.json` records and must name its pinned commit in its header, and its unpacked files must have the `filesSha256` that `tool/grammars.json` or `tool/toolchain.json` records at the checked-out tag. That last check holds a bundle to the tagged repository rather than to the `build_info.json` downloaded beside it. A release also attaches what the pinned CLI generated for the two grammars that commit no `parser.c` (latex and swift), so a rebuild runs no CLI and downloads nothing: each of those bundles must have the sha256 `build_info.json` records, and its files the `generatedSha256` that `tool/grammars.json` records at the tag. The same bytes come back from the same Xcode installed at the same path, whose clang compiles every library and whose git writes the source bundles, with the same macOS `/usr/bin/gzip` and `/usr/bin/tar`: `build_info.json` records all four, and since the archive carries `build_info.json` with every bundle's sha256, its bytes depend on them too. `build_info.json` also records the absolute paths of clang and of the macOS SDK, which is passed to every compile as `-isysroot`, so the same Xcode installed elsewhere, for example as `/Applications/Xcode-26.0.app`, packs a different archive.

## License

This repository's own work (its tools, tests, patches and the query files written here) is under the MIT licence in `LICENSE`; a file a patch modifies stays under its grammar's licence as well. The tree-sitter runtime, each grammar and the query files that come from nvim-treesitter or from a grammar's own repository keep their own licences. `THIRD_PARTY_NOTICES.md` reproduces every one of them verbatim, lists where each query file came from, and travels in the release archive; `LICENSES/Apache-2.0.txt` is nvim-treesitter's licence.

Every query file derived from nvim-treesitter opens with a header naming the nvim-treesitter file and commit it derives from and whether it was modified here, as `tool/query_provenance.json` records. `dart run tool/check_query_provenance.dart` checks the provenance and the headers, and `--write-headers` writes the headers.

`THIRD_PARTY_NOTICES.md` is generated from the pinned sources, the query provenance and the licence files, and the build refuses to run while the committed copy differs from what it generates. `tool/write_notices.dart` also reads the root licence and NOTICE files at every upstream commit `tool/query_provenance.json` cites, fetching the commit into `grammars/<repo>` or `.cache/nvim-treesitter` when the store lacks it, and fails unless they are exactly the ones the notices reproduce for that repository (the grammar's at its pin, or `LICENSES/Apache-2.0.txt`), so no query file is attributed to a licence its cited commit does not carry. After changing a pin, a query file's provenance or a licence, regenerate it and commit the result:

```bash
dart run tool/write_notices.dart           # rewrite THIRD_PARTY_NOTICES.md
dart run tool/write_notices.dart --check   # exit 1 unless it is current
```

The build also refuses a grammar with no licence file at its root, and a licence or NOTICE file that is not UTF-8 text. It reads every source the runtime or a grammar compiles (a grammar's `src/tree_sitter/` headers and the runtime's `lib/src/unicode/` headers apart, which the tree-sitter and ICU licences cover) for licence statements: a comment that mentions a copyright, a licence, an SPDX identifier, the public domain, a permission grant, a reservation of rights, `©` or `(c)`. Such a source must be named in `extraNotices`, the grammar's in `tool/grammars.json` or the runtime's in `tool/toolchain.json`, so the notices reproduce its licence comments; a line comment runs on across consecutive `//` lines. A source that mentions any of those words outside its comments, for example in a string, is refused whatever `extraNotices` says, since only a comment can be reproduced.
