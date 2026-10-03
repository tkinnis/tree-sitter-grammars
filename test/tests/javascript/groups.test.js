// The groups a test is registered under, each named in plain text.

test('at the top of the file', () => {});

describe('outer alpha', () => {
  it('works', () => {});

  describe.skip(`inner, a template with no substitution`, function () {
    test.only('two levels down', async () => {});
  });

  context('a context', () => it('is its body'));

  suite.only.concurrent('two modifiers', () => {
    xit('is skipped', () => {});
  });

  describe.if(true)('registered where a condition holds', () => {
    it.each([1, 2])('runs a row %i', (n) => {});
    it.each`
      n
      ${1}
    `('runs a tagged row $n', ({ n }) => {});
  });

  describe('times out', () => {
    test('in time', () => {});
  }, 5000);
});

fdescribe('focused', () => {
  xdescribe("skipped, in double quotes", () => {
    it('is still read', () => {});
  });
});
