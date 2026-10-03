// A group function imported from the runner's own module is the runner's.

import { describe, it, test } from '@jest/globals';
import { suite as group } from './helpers';

describe('imported', () => {
  it('works', () => {});
});

test('at the top of the file', () => {});
