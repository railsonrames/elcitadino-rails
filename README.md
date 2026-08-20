# README

This README would normally document whatever steps are necessary to get the
application up and running.

## Configuration

- `APP_TIMEZONE` — the app's default display timezone (e.g. `"Madrid"`,
  `"America/Sao_Paulo"`). Defaults to `"Madrid"`. Database storage is always
  UTC regardless of this setting (`config.active_record.default_timezone`);
  this only controls the zone used to display/interpret times when no
  more specific zone applies. Set per deployment when expanding to a new
  market instead of editing `config/application.rb`.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
