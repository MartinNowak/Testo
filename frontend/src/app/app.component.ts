import { Component } from '@angular/core';
import { Runner } from './api';
import { BackendService } from './backend.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styles: []
})
export class AppComponent {
  runners: Runner[] = [];

  constructor(private backend: BackendService) {
    this.backend.runners().subscribe(runners => this.runners = runners);
  }
}
