@Component({ selector: 'app-panel' })
export class Panel {
  @Input() label: string;

  constructor(@Inject(TOKEN) private readonly store: Store) {
    this.url = new URL(store.href);
    this.limit = LIMIT();
  }

  @HostListener.of('click')
  @Output.emitter
  handle(): void {}
}
