# Security

## Reporting

Please do not open a public issue for a vulnerability. Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) on this repository, which reaches the maintainer without disclosing anything.

This is a small project maintained by one person. There is no guaranteed response window; a real report will be taken seriously, and its receipt acknowledged.

## What a release contains

Each release is one archive of compiled tree-sitter grammars, their query files and the tree-sitter runtime, for macOS on Apple Silicon. Every grammar and the runtime are built from a commit pinned in `tool/grammars.json` and `tool/toolchain.json`, with the exact compiler flags recorded in the release's `build_info.json`, and the archive's sha256 is published with it. A consumer such as [Finch](https://github.com/tkinnis/finch) pins that sha256 and refuses any other archive.

Reports that matter most here:

- an archive whose contents differ from what its pinned sources build;
- a grammar or query that crashes, hangs or corrupts memory in the runtime when parsing or querying an input — the `test/crashes` fixtures exist for exactly this;
- a patch under `patches/` that changes behaviour beyond what it states.
