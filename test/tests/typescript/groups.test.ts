// The groups a test is registered under, in a typed file.

import { describe, expect, it, test } from "bun:test";

type Row = { upto: number; total: number };

describe("outer alpha", () => {
  it("works", (): void => {
    expect(1 as number).toBe(1);
  });

  describe("inner", () => {
    test.each<Row>([{ upto: 1, total: 1 }])("row $upto", ({ upto }: Row) => {});
  });
});

describe.each<[string]>([["alpha"]])("per row %s", (label: string) => {
  it("in a group per row", () => {});
});

function helper(name: string): void {
  it(`registered by ${name}`, () => {});
}

test("at the top of the file", () => {});
