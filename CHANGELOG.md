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

