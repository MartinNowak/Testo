import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { HttpModule } from '@angular/http';

import { AppRoutingModule } from './app-routing.module';

import { AppComponent } from './app.component';
import { RunnerComponent } from './runner/runner.component';
import { BuildComponent } from './build/build.component';
import { BackendService } from './backend.service';


@NgModule({
  declarations: [
    AppComponent,
    RunnerComponent,
    BuildComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    HttpModule
  ],
  providers: [
    BackendService,
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
