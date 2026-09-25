import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/git.dart';

void main() {
  const parent = {
    'PATH': '/usr/bin',
    'HOME': '/home/user',
    'GIT_DIR': '/elsewhere/.git',
    'GIT_WORK_TREE': '/elsewhere',
    'GIT_CONFIG_GLOBAL': '/home/user/hostile',
    'GIT_CONFIG_SYSTEM': '/etc/hostile',
    'GIT_CONFIG_PARAMETERS': "'core.autocrlf'='true'",
    'GIT_CONFIG_COUNT': '1',
    'GIT_CONFIG_KEY_0': 'core.eol',
    'GIT_CONFIG_VALUE_0': 'crlf',
    'GIT_ATTR_SOURCE': 'HEAD~1',
  };

  test('gitEnvironment drops only the repository location variables', () {
    check(gitEnvironment(parent))
      ..not((it) => it.containsKey('GIT_DIR'))
      ..not((it) => it.containsKey('GIT_WORK_TREE'))
      ..containsKey('GIT_CONFIG_PARAMETERS')
      ..containsKey('HOME');
  });

  test('isolatedGitEnvironment reads no configuration outside the store', () {
    check(isolatedGitEnvironment(parent)).deepEquals({
      'PATH': '/usr/bin',
      'HOME': '/home/user',
      'GIT_CONFIG_GLOBAL': '/dev/null',
      'GIT_CONFIG_NOSYSTEM': '1',
      'GIT_ATTR_NOSYSTEM': '1',
      'GIT_NO_REPLACE_OBJECTS': '1',
    });
  });
}
