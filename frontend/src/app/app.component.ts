import { Component, ChangeDetectionStrategy } from '@angular/core';
import { Runner } from './api';
import { BackendService } from './backend.service';
import 'rxjs/add/operator/pluck';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class AppComponent {
  runners: Runner[] = [];

  constructor(private backend: BackendService) {
    this.backend.runners().subscribe(runners => this.runners = runners);
  }
}
