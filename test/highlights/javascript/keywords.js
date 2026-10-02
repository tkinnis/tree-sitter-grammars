/**
 * Counts what is left.
 */
export async function count(items) {
  for (const item of items) {
    if (typeof item === 'number') return await item;
  }
  throw new Error('none');
}
