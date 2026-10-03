// The groups a test is registered under, in a file holding JSX.

import { describe, it } from "vitest";

const Greeting = ({ name }: { name: string }) => <p>Hello, {name}</p>;

describe("Greeting", () => {
  it("renders a name", () => {
    const element = <Greeting name="finch" />;
  });

  describe.each([["alpha"]])("per row %s", (label) => {
    it("renders a row", () => {});
  });
});

it("at the top of the file", () => {});
