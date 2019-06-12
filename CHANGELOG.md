# CHANGELOG

# Unreleased

* [#59](https://github.com/gocardless/coach/pull/59) Request data included in the
  `request.coach` event includes a `session_ip` field which replaces the erroneously named
  `session_id`. The latter is deprecated and will be removed in a future release.

* [#60](https://github.com/gocardless/coach/pull/60) Add `Middleware.requires?`, which
  behaves like `Middleware.provides?` but for requirements.

## Breaking changes

* [#70](https://github.com/gocardless/coach/pull/70) The following deprecated event names have been removed:
  * `coach.handler.start`
  * `coach.middleware.start`
  * `coach.middleware.finish`
  * `coach.handler.finish`
  * `coach.request`

# 1.0.0 / 2018-04-19

## Breaking changes

* [#41](https://github.com/gocardless/coach/pull/41) Ruby versions before 2.1 are no
longer supported.
* [#29](https://github.com/gocardless/coach/pull/29) To use Coach's included matchers
in RSpec, you should now `require coach/rspec`. `Coach.require_matchers!` is deprecated
and will be removed in a future version.
* [#47](https://github.com/gocardless/coach/pull/47) If you're using Coach's support for
[instrumentation](https://github.com/gocardless/coach#instrumentation) with
`ActiveSupport::Notifications`, the event names Coach publishes have changed to be more
consistent with other libraries. The previous names will work for now, but will be removed in a future version. The changes are as follows:

| Before                  | After                   |
| ----------------------- | ------------------------|
| coach.handler.start     | start_handler.coach     |
| coach.middleware.start  | start_middleware.coach  |
| coach.middleware.finish | finish_middleware.coach |
| coach.handler.finish    | finish_handler.coach    |
| coach.request           | request.coach           |

# 0.5.1 / 2017-08-21

* [#26](https://github.com/gocardless/coach/pull/26) Add `started_at` to the
  request event metadata.

# 0.5.0 / 2017-08-07

* [#24](https://github.com/gocardless/coach/pull/24) Use
  ActiveSupport.instrument for coach.handler.finish event. Potentially breaking
  change as the coach.handler.finish subscribers may trigger twice, depending on
  how users have subscribed to them.

# 0.4.6

* [#22](https://github.com/gocardless/coach/pull/22) Publish ActiveSupport notifications
  even on errors

# 0.4.5 / 2017-04-26

* [#17](https://github.com/gocardless/coach/pull/17) Only require rspec/expectations
  when adding new matchers
* [#18](https://github.com/gocardless/coach/pull/18) Properly pin version of rubocop

# 0.4.4 / 2016-08-26

* [#16](https://github.com/gocardless/coach/pull/16) Fix middleware lookup issue in router

# 0.4.3 / 2016-05-07

* [#15](https://github.com/gocardless/coach/pull/15) Clean up `Coach::Handler#inspect`

# 0.4.2 / 2016-05-07

* [#13](https://github.com/gocardless/coach/pull/13) Add support for Rails 5.

# 0.4.1 / 2016-03-09

* [#10](https://github.com/gocardless/coach/pull/10) Removed a dependency that Coach's RSpec matchers had on Rails' `.third` array method.

# 0.4.0 / 2015-12-21

* `Coach::Router.new` now accepts a `ActionDispatch::Routing::Mapper`, rather
  than a `Rails::Application`. This means that when initialising a
  `Coach::Router` from within a `routes.draw` block, you may now pass `self` to
  the router, preserving surrounding context (e.g. block-level scopes).


# 0.3.0 / 2015-11-24

* Allow Handler to take a config hash, just like Middleware


# 0.2.3 / 2015-08-24

* Allow config values to be inherited


# 0.2.2 / 2015-07-17

* Diagramatic errors of missing requirements


# 0.2.1 / 2015-06-29

* Logging of metadata with ActiveSupport notifications


# 0.2.0 / 2015-06-17

Initial public release. This library is in beta until it hits 1.0, so backwards
incompatible changes may be made in minor version releases.

