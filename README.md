<img src="logo.svg" width="200" alt="Logo">

Simple, self-hosted CI system using [GitLab Runner](https://docs.gitlab.com/runner/) as executor.

## Setup

- Deploy single binary, no dependencies
- [Register Github OAuth2 application](https://github.com/settings/applications/new) (also see [Authorization options for OAuth Apps](https://developer.github.com/apps/building-oauth-apps/authorization-options-for-oauth-apps/#web-application-flow))
- Configure Github OAuth2 and admin users (see [config.sample.yml](config.sample.yml))
