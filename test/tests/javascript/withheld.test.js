// Tests whose groups the source does not say.

const label = 'by a variable';

describe(label, () => {
  it('in a group named by a variable', () => {});
});

describe(`with ${label}`, () => {
  it('in a group named by a substitution', () => {});
});

describe('it\'s escaped', () => {
  it('in a group named with an escaped quote', () => {});
});

describe('escaped\tby a tab', () => {
  it('in a group named with an escape', () => {});
});

describe('', () => {
  it('in a group named by nothing', () => {});
});

describe.each([['alpha'], ['beta']])('per row %s', (name) => {
  it('in a group per row', () => {});
});

describe.only.each`
  name
  ${'gamma'}
`('per tagged row $name', ({ name }) => {
  it('in a group per tagged row', () => {});
});

describe.for(['delta'])('per row of for %s', (name) => {
  it('in a group per row of for', () => {});
});

describe('holds a loop', () => {
  for (const n of [1, 2]) {
    it(`registered by a loop ${n}`, () => {});
  }

  [1, 2].forEach((n) => {
    it('registered in a callback', () => {});
  });

  [3].map((n) => it('registered by an arrow body'));

  beforeEach(() => {
    it('registered in a hook', () => {});
  });

  it('first on its line', () => {}); it('second on its line', () => {});
});

function registersUnderItsCaller() {
  it('registered by a helper', () => {});
}

registersUnderItsCaller();

it('helped', function () {
  it('nested in a test', () => {});
});
