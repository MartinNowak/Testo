import { Component, Input } from '@angular/core';
import { Runner } from '../api';

@Component({
  selector: 'runner',
  template: `
    <p>
      {{ runner.name }}
      <span [ngClass]="runner.active ? 'active' : 'inactive'">●</span>
      {{ runner.lastConnection }}
    </p>
  `,
  styles: ["span.active { color: green; }", "span.inactive { color: red; }"]
})
export class RunnerComponent {
  @Input() runner: Runner;
  constructor() {}
}
