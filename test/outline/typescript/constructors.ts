enum Mode {
  Idle,
  Active,
}

class Worker {
  public constructor(private readonly mode: Mode = Mode.Idle) {}

  run(): Mode {
    return this.mode;
  }
}

abstract class BaseRunner {
  protected constructor() {}

  abstract step(): void;
}
