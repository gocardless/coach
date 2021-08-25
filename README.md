# Coach

[![Gem Version](https://badge.fury.io/rb/coach.svg)](http://badge.fury.io/rb/coach)
[![CircleCI](https://circleci.com/gh/gocardless/coach.svg?style=svg)](https://circleci.com/gh/gocardless/coach)
[![Code Climate](https://codeclimate.com/github/gocardless/coach.svg)](https://codeclimate.com/github/gocardless/coach)

Coach improves your controller code by encouraging:

- **Modularity** - No more tangled `before_filter`'s and interdependent concerns. Build
  Middleware that does a single job, and does it well.
- **Guarantees** - Work with a simple `provide`/`require` interface to guarantee that your
  middlewares load data in the right order when you first boot your app.
- **Testability** - Test each middleware in isolation, with effortless mocking of test
  data and natural RSpec matchers.

For our policy on compatibility with Ruby and Rails versions, see [COMPATIBILITY.md](docs/COMPATIBILITY.md).

# Installation

To get started, just add Coach to your `Gemfile`, and then run `bundle`:

```ruby
gem 'coach'
```

Coach works with Ruby versions 2.6 and onwards.

## Coach by example

The best way to see the benefits of Coach is with a demonstration.

### Mounting an endpoint

```ruby
class HelloWorld < Coach::Middleware
  def call
    # Middleware return a Rack response
    [ 200, {}, ['hello world'] ]
  end
end
```

So we've created ourselves a piece of middleware, `HelloWorld`. As you'd expect,
`HelloWorld` simply outputs the string `'hello world'`.

In an example Rails app, called `Example`, we can mount this route like so...

```ruby
Example::Application.routes.draw do
  match "/hello_world",
        to: Coach::Handler.new(HelloWorld),
        via: :get
end
```

Once you've booted Rails locally, the following should return `'hello world'`:

```sh
$ curl -XGET http://localhost:3000/hello_world
```

### Zeitwerk

The new default autoloader in Rails 6+ is [Zeitwerk](https://github.com/fxn/zeitwerk), which removes
support for autoloading constants during app boot, which that example would do - either you have to
`require "hello_world"` in your routes file, or avoid referencing the `HelloWorld` constant until
the app has booted. To avoid that, you can instead pass the module or middleware _name_ to
`Handler.new`, for example:

```ruby
Example::Application.routes.draw do
  match "/hello_world",
        to: Coach::Handler.new("HelloWorld"),
        via: :get
```

### Building chains

Suppose we didn't want just anybody to see our `HelloWorld` endpoint. In fact, we'd like
to lock it down behind some authentication.

Our request will now have two stages, one where we check authentication details and
another where we respond with our secret greeting to the world. Let's split into two
pieces, one for each of the two subtasks, allowing us to reuse this authentication flow in
other middlewares.

```ruby
class Authentication < Coach::Middleware
  def call
    unless User.exists?(login: params[:login])
      return [ 401, {}, ['Access denied'] ]
    end

    next_middleware.call
  end
end

class HelloWorld < Coach::Middleware
  uses Authentication

  def call
    [ 200, {}, ['hello world'] ]
  end
end
```

Here we detach the authentication logic into its own middleware. `HelloWorld` now `uses`
`Authentication`, and will only run if it has been called via `next_middleware.call` from
authentication.

Notice we also use `params` just like you would in a normal Rails controller. Every
middleware class will have access to a `request` object, which is an instance of
`ActionDispatch::Request`.

### Passing data through middleware

So far we've demonstrated how Coach can help you break your controller code into modular
pieces. The big innovation with Coach, however, is the ability to explicitly pass your
data through the middleware chain.

An example usage here is to create a `HelloUser` endpoint. We want to protect the route by
authentication, as we did before, but this time greet the user that is logged in. Making
a small modification to the `Authentication` middleware we showed above...

```ruby
class Authentication < Coach::Middleware
  provides :user  # declare that Authentication provides :user

  def call
    return [ 401, {}, ['Access denied'] ] unless user.present?

    provide(user: user)
    next_middleware.call
  end

  def user
    @user ||= User.find_by(login: params[:login])
  end
end

class HelloUser < Coach::Middleware
  uses Authentication
  requires :user  # state that HelloUser requires this data

  def call
    # Can now access `user`, as it's been provided by Authentication
    [ 200, {}, [ "hello #{user.name}" ] ]
  end
end

# Inside config/routes.rb
Example::Application.routes.draw do
  match "/hello_user",
        to: Coach::Handler.new("HelloUser"),
        via: :get
end
```

Coach analyses your middleware chains whenever a new `Handler` is created, or when the handler is
first used if the route is being lazy-loaded (i.e., if you're passing a string name, instead of the
route itself). If any middleware `requires :x` when its chain does not provide `:x`, we'll error out
before the app even starts with the error:

```ruby
Coach::Errors::MiddlewareDependencyNotMet: HelloUser requires keys [user] that are not provided by the middleware chain
```

This static verification eradicates an entire category of errors that stem from implicitly
running code before hitting controller methods. It allows you to be confident that the
data you require has been loaded, and makes tracing the origin of that data as simple as
looking up the chain.

## Configuring middlewares

By making use of middleware config hashes, you can build generalised middlewares that can
be configured specifically for the chain that they are used in.

```ruby
class Logger < Coach::Middleware
  def call
    # Logs the incoming request path, with a configured prefix
    Rails.logger.info("[#{config[:prefix]}] - #{request.path}")
    next_middleware.call
  end
end

class HelloUser < Coach::Middleware
  uses Logger, prefix: 'HelloUser'
  uses Authentication

  def call
    ...
  end
end
```

The above configures a `Logger` middleware to prefix it's log entries with `'HelloUser'`.
This is a contrived example, but at GoCardless we've created middlewares that can act as
generalised resource endpoints (show, index, etc) when given the model class and some
extra configuration.

## Testing

The basic strategy is to test each middleware in isolation, covering all the edge cases,
and then create request specs that cover a happy code path, testing each of the
middlewares while they work in sequence.

Each middleware is encouraged to rely on data passed through the `provide`/`require`
syntax exclusively, except in stateful operations (such as database queries). By sticking
to this rule, testing becomes as simple as mocking a `context` hash.

Coach comes with some RSpec matchers to help simplify your testing, however they aren't
required by default. You'll need to run `require 'coach/rspec'`, we recommend putting this
in your `spec/spec_helper.rb` or `spec/rails_helper.rb` file.

```ruby
require 'spec_helper'

describe "/whoami" do
  let(:user) { FactoryGirl.create(:user, name: 'Clark Kent', token: 'Kryptonite') }

  context "with correct auth details" do
    it "responds with user name" do
      get "/whoami", {}, { 'Authorization' => 'Kryptonite' }
      expect(response.body).to match(/Clark Kent/)
    end
  end
end

describe Routes::Whoami do
  subject(:instance) { described_class.new(context) }
  let(:context) { { authenticated_user: double(name: "Clark Kent") } }

  it { is_expected.to respond_with_body_that_matches(/Clark Kent/) }
end

describe Middleware::AuthenticatedUser do
  subject(:instance) { described_class.new(context) }
  let(:context) do
    { request: instance_double(ActionDispatch::Request, headers: headers) }
  end

  let(:user) { FactoryGirl.create(:user, name: 'Clark Kent', token: 'Kryptonite') }

  context "with valid token" do
    it { is_expected.to call_next_middleware }
    it { is_expected.to provide(authenticated_user: user) }
  end

  context "with invalid token" do
    it { is_expected.to respond_with_status(401) }
    it { is_expected.to respond_with_body_that_matches(/access denied/i) }
  end
end
```

## Routing

For routes that represent resource actions, Coach provides some syntactic sugar to
allow concise mapping of endpoint to handler in Rails apps.

```ruby
# config/routes.rb
Example::Application.routes.draw do
  router = Coach::Router.new(self)
  router.draw(Routes::Users,
              base: "/users",
              actions: [
                :index,
                :show,
                :create,
                :update,
                disable: { method: :post, url: "/:id/actions/disable" }
              ])
end
```

Default actions that conform to standard REST principles can be easily loaded, with the
users resource being mapped to:

| Method | URL                          | Description                                    |
|--------|------------------------------|------------------------------------------------|
| `GET`  | `/users`                     | Index all users                                |
| `GET`  | `/users/:id`                 | Get user by ID                                 |
| `POST` | `/users`                     | Create new user                                |
| `PUT`  | `/users/:id`                 | Update user details                            |
| `POST` | `/users/:id/actions/disable` | Custom action routed to the given path suffix  |

If you're using Zeitwerk, you can pass the name of the module to `#draw`, instead of the module
itself.

```ruby
# config/routes.rb
Example::Application.routes.draw do
  router = Coach::Router.new(self)
  router.draw("Routes::Users",
              base: "/users",
              actions: [
                :index,
                :show,
                :create,
                :update,
                disable: { method: :post, url: "/:id/actions/disable" }
              ])
end
```

## Rendering

By now you'll probably agree that the rack response format isn't the nicest way to render
responses. Coach comes sans renderer, and for a good reason.

We initially built a `Coach::Renderer` module, but soon realised that doing so would
prevent us from open sourcing. Our `Renderer` was 90% logic specific to the way our APIs
function, including handling/formatting of validation errors, logging of unusual events
etc.

What worked well for us is a standalone `Renderer` class that we could require in all our
middleware that needed to format responses. This pattern also led to clearer code -
consistent with our preference for explicit code, stating `Renderer.new_resource(...)` is
instantly more debuggable than an inherited method on all middlewares.

## Instrumentation

Coach uses `ActiveSupport::Notifications` to issue events that can be used to profile
middleware.

Information for how to use `ActiveSupport`s notifications can be found
[here](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html).


| Event                         | Arguments                                              |
|-------------------------------|------------------------------------------------------- |
| `start_handler.coach`     | `event(:middleware, :request)`                         |
| `start_middleware.coach`  | `event(:middleware, :request)`                         |
| `finish_middleware.coach` | `start`, `finish`, `id`, `event(:middleware, :request)`|
| `finish_handler.coach`    | `start`, `finish`, `id`, `event(:middleware, :request)`|
| `request.coach`           | `event` containing request data and benchmarking       |

Of special interest is `request.coach`, which publishes statistics on an entire
middleware chain and request. This data is particularly useful for logging, and is our
solution to Rails `process_action.action_controller` event emitted on controller requests.

The benchmarking data includes information on how long each middleware took to process,
along with the total duration of the chain.

For coach to emit `request.coach` events, it first needs to be subscribed to handler/middleware events:

```ruby
Coach::Notifications.subscribe!

# Now you can subscribe to and use request.coach events, e.g.
ActiveSupport::Notifications.subscribe("request.coach") do |_, event|
  Rails.logger.info(event)
end
```

You can add additional metadata to the notifications published by Coach by calling the
`log_metadata` method from inside your Coach middlewares.

```ruby
class Tracking < Coach::Middleware
  requires :user

  def call
    log_metadata(user_id: user.id)
    next_middleware.call
  end
end
```

# Coach CLI

As well as the library, the Coach gem comes with a command line tool - `coach`.

When working in a large codebase that uses Coach, one of the challenges you may run into
is understanding the `provide`/`require` graph made up of all the middleware chains you've
built. While the library enforces the correctness of those chains at boot time, it doesn't
help you understand those dependencies. That's where the `coach` CLI comes in!

Currently, the `coach` CLI supports two commands.

## `find-provider`

`find-provider` is the simpler of the two commands. Given the name of a Coach middleware
and a value that it requires, it outputs the name of the middleware that provides it.

```bash
$ bundle exec coach find-provider HelloUser user
Value `user` is provided to `HelloUser` by:

Authentication
```

If there are multiple middlewares in the chain that provide the same value, all of them
will be listed.

## `find-chain`

`find-chain` is the more advanced of the two commands, and is most useful in larger
codebases. Given the name of a Coach middleware and a value it requires, it outputs the
chains of middleware between the specified middleware and the one that provides the
required value.

```bash
# Note that we've assumed an intermediate middleware - `UserDecorator` exists in this
# example to make the functionality of the command clearer.
$ bundle exec coach find-chain HelloUser user
Value `user` is provided to `HelloUser` by:

HelloUser -> UserDecorator -> Authentication
```

If there are multiple paths to a middleware that provides that value, all of them will be
listed. Similarly, if multiple middlewares provide the same value, all of them will be
listed.

## Spring integration

Given that the Coach CLI is mostly aimed at large Rails apps using Coach, it would be an
oversight for us not to integrate it with [Spring](https://github.com/rails/spring/).

To enable the use of Spring with the Coach CLI, add the following to `config/spring.rb` or
an equivalent Rails config file.

```ruby
require "spring/commands/coach"
```

On GoCardless' main Rails app, using Spring reduces the time to run `coach` commands from
around 15s to 1s.

## Future work

While we think the commands we've already built are useful, we do have some ideas to go
further, including:

  - Better formatting of provider chains
  - Outputting DOT format files to visualise with Graphviz
  - Editor integrations (e.g. showing the provider chains when hovering a `requires`
    statement)

# License & Contributing

* Coach is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
* Bug reports and pull requests are welcome on GitHub at https://github.com/gocardless/coach.

GoCardless ♥ open source. If you do too, come [join us](https://gocardless.com/about/jobs).
