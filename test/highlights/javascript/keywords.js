import { default as read } from './read';
export { default as parse } from './parse';
export * as default from './all';

/**
 * Counts what is left.
 */
export async function count(items) {
  for (const item of items) {
    if (typeof item === 'number') return await item;
  }
  throw new Error('none');
}
