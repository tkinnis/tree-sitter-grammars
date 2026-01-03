import 'dart:io';

void main() async {
  final treeSitterDir = Directory('tree-sitter');
  if (!treeSitterDir.existsSync()) {
    print('Cloning tree-sitter...');
    await Process.run('git', [
      'clone',
      'https://github.com/tree-sitter/tree-sitter',
      treeSitterDir.path,
    ]);
  }

  print('Building tree-sitter...');
  await Process.run('make', [], workingDirectory: treeSitterDir.path);

  final outputDir = Directory('output');
  if (!outputDir.existsSync()) {
    await outputDir.create(recursive: true);
  }

  const libPath = 'tree-sitter/libtree-sitter.dylib';
  const newLibPath = 'output/libtree-sitter.dylib';
  await File(libPath).copy(newLibPath);
  print('Copied libtree-sitter.dylib to output/');
}
