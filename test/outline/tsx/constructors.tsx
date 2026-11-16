enum Tone {
  Muted,
  Loud,
}

class Badge {
  constructor(private readonly label: string) {}

  render() {
    return <span>{this.label}</span>;
  }
}
