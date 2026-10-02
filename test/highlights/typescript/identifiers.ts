import React from 'react';

function Make(limit: number): Set<number> {
  const seen = new Set<number>();
  const count = parseInt('1') < limit ? Math.max(limit, 1) : eval('0');
  Make(count);
  return seen;
}
