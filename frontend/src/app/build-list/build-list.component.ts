import { Component, OnInit, ChangeDetectionStrategy } from '@angular/core';

@Component({
  template: `
    <p>
      build-list works!
    </p>
  `,
  styles: [],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class BuildListComponent implements OnInit {

  constructor() { }

  ngOnInit() {
  }

}
