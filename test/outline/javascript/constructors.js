class Counter {
  constructor(initial = 0) {
    this.value = initial;
  }

  increment() {
    this.value += 1;
  }
}

const Named = class Box {
  constructor() {}

  open() {}
};

function reset(counter) {
  counter.increment();
}
