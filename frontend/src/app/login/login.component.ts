import { Component, ChangeDetectionStrategy } from '@angular/core';

@Component({
  template: `
    <a href="api/oauth2/github">
      <img src="assets/img/GitHub-Mark-120px-plus.png">
      Login With GitHub
    </a>
    <a href="api/oauth2/bitbucket">
      <img src="assets/img/BitBucket.png">
      Login With BitBucket
    </a>
    <a href="api/oauth2/gitlab">
      <img src="assets/img/GitLab.png">
      Login With GitLab
    </a>
  `,
  styleUrls: ['./login.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class LoginComponent {
  constructor() {
  }
}
