import { Component, OnInit, Input, ChangeDetectionStrategy } from '@angular/core';
import { Runner } from '../api';

@Component({
  template: `
    <runner *ngFor="let r of runners"
        [runner]="r">
    </runner>
  `,
  styles: [],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class RunnerListComponent implements OnInit {
  //@Input() runners$: Runner[];
  @Input() runners: Runner[];

  constructor() { }

  ngOnInit() {
  }

}
