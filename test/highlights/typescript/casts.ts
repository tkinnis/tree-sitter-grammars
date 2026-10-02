import { parse as read } from './parse';

/** The parsed count. */
export const count = read('1') as number;

export interface Counted {
  count: number;
}
