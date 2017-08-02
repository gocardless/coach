# Unreleased changes

# 0.4.6

* [https://github.com/gocardless/coach/pull/22](#22) Publish ActiveSupport notifications
  even on errors

# 0.4.5 / 2017-04-26

* [https://github.com/gocardless/coach/pull/17] Only require rspec/expectations
  when adding new matchers
* [https://github.com/gocardless/coach/pull/18] Properly pin version of rubocop

# 0.4.4 / 2016-08-26

* [https://github.com/gocardless/coach/pull/16] Fix middleware lookup issue in router

# 0.4.3 / 2016-05-07

* [https://github.com/gocardless/coach/pull/15] Clean up `Coach::Handler#inspect`

# 0.4.2 / 2016-05-07

* [https://github.com/gocardless/coach/pull/13] Add support for Rails 5.

# 0.4.1 / 2016-03-09

* [https://github.com/gocardless/coach/pull/10] Removed a dependency that Coach's RSpec matchers had on Rails' `.third` array method.

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

