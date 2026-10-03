// A parameter named after a group function rebinds it inside the body.

export function register(describe: (name: string, body: () => void) => void): void {
  describe("through a parameter", () => {
    it("is under whatever was passed", () => {});
  });
}
