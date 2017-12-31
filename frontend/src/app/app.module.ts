import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';
import { HttpModule } from '@angular/http';
import { Routes, RouterModule } from '@angular/router';


import { AppRoutingModule } from './app-routing.module';

import { AppComponent } from './app.component';
import { RunnerComponent } from './runner/runner.component';
import { BuildComponent } from './build/build.component';
import { BackendService } from './backend.service';
import { LoginComponent } from './login/login.component';
import { BuildListComponent } from './build-list/build-list.component';
import { RunnerListComponent } from './runner-list/runner-list.component';
import { ProjectListComponent } from './project-list/project-list.component';
import { PageNotFoundComponent } from './page-not-found/page-not-found.component';

import { environment } from '../environments/environment';

const appRoutes: Routes = [
  { path: '', redirectTo: '/builds', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'builds', component: BuildListComponent },
  { path: 'projects', component: ProjectListComponent },
  { path: 'runners', component: RunnerListComponent },
  { path: '**', component: PageNotFoundComponent },
];

@NgModule({
  declarations: [
    AppComponent,
    RunnerComponent,
    BuildComponent,
    LoginComponent,
    BuildListComponent,
    RunnerListComponent,
    PageNotFoundComponent,
    ProjectListComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    HttpModule,
    RouterModule.forRoot(
      appRoutes,
      { enableTracing: false }
    )
  ],
  providers: [
    BackendService,
  ],
  bootstrap: [AppComponent]
})
export class AppModule { }
