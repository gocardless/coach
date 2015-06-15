# Coach

[![Gem Version](https://badge.fury.io/rb/coach.svg)](http://badge.fury.io/rb/coach)
[![Build Status](https://travis-ci.org/gocardless/coach.png?branch=master)](https://travis-ci.org/gocardless/coach)
[![Code Climate](https://codeclimate.com/github/gocardless/coach.png)](https://codeclimate.com/github/gocardless/coach)

Coach improves your controller code by encouraging...

- **Modularity** - No more tangled `before_filter`'s and interdependent concerns. Build
  Middleware that does a single job, and does it well.
- **Guarantees** - Work with a simple `provide`/`require` interface to guarantee that your
  middlewares load data in the right order when you first boot your app.
- **Testability** - Test each middleware in isolation, with effortless mocking of test
  data and natural RSpec matchers.

## Simple endpoint

Lets start by creating a simple endpoint.

```ruby
module Routes
  class Echo < Coach::Middleware
    def call
      # All middleware should return rack compliant responses
      [ 200, {}, [params[:word]] ]
    end
  end
end
```

Any Middlewares have access to the `request` handle, which is an instance of
`ActionDispatch::Request`. This also parses the request params, and these are made
available inside Middlewares as `params`.

In an example Rails app, called `Example`, we can mount this route like so...

```ruby
Example::Application.routes.draw do
  match "/echo/:word",
        to: Coach::Handler.new(Routes::Echo),
        via: :get
end
```

Once booting Rails locally, running `curl -XGET http://localhost:3000/echo/hello` should
respond with `'hello'`.

## Building chains

Lets try creating a route protected by authentication.

```ruby
module Routes
  class Secret < Coach::Middleware
    def call
      unless User.exists?(id: params[:user_id], password: params[:user_password])
        return [ 401, {}, ['Access denied'] ]
      end

      [ 200, {}, ['super-secretness'] ]
    end
  end
end
```

The above will verify that a user can be found with the given params, and if it cannot
then will respond with a `401`.

This does what we want it to do, but why should `Secret` know anything about
authentication? This complicates `Secret`'s design and prevents reuse of authentication
logic.

```ruby
module Middleware
  class Authentication < Coach::Middleware
    def call
      unless User.exists?(id: params[:user_id], password: params[:user_password])
        return [ 401, {}, ['Access denied'] ]
      end

      next_middleware.call
    end
  end
end

module Routes
  class Secret < Coach::Middleware
    uses Middleware::Authentication

    def call
      [ 200, {}, ['super-secretness'] ]
    end
  end
end
```

Here we detach the authentication logic into it's own middleware. `Secret` now `uses`
`Middleware::Authentication`, and will only run if it has been called via
`next_middleware.call` from authentication.

## Passing data through middleware

Now what happens if you have an endpoint that returns the current auth'd users details? We
can maintain the separation of authentication logic and endpoint as below...

```ruby
module Middleware
  class AuthenticatedUser < Coach::Middleware
    provides :authenticated_user

    def call
      user = User.find_by(token: request.headers['Authorization'])
      return [ 401, {}, ['Access denied'] ] unless user.exists?

      provide(authenticated_user: user)
      next_middleware.call
    end
  end
end

module Routes
  class Whoami < Coach::Middleware
    uses AuthenticatedUser
    requires :authenticated_user

    def call
      [ 200, {}, [authenticated_user.name] ]
    end
  end
end
```

Each middleware declares what it requires from those that have ran before it, and what it
will provide to those that run after. Whenever a middleware chain is mounted, these
requirements will be verified. In the above, if our `Whoami` middleware had neglected to use
`AuthenticatedUser`, then mounting would fail with the error...

    Coach::Errors::MiddlewareDependencyNotMet: AuthenticatedUser requires keys [authenticated_user] that are not provided by the middleware chain

This static verification eradicates an entire category of errors that stem from implicitly
running code before hitting controller methods. It allows you to be confident that the
data you require has been loaded, and makes tracing the origin of that data as simple as
looking up the chain.

## Testing

The basic strategy is to test each middleware in isolation, covering all the edge cases,
and then create request specs that cover a happy code path, testing each of the
middlewares while they work in sequence.

Each middleware is encouraged to rely on data passed through the `provide`/`require`
syntax exclusively, except in stateful operations (such as database queries). By sticking
to this rule, testing becomes as simple as mocking a `context` hash.

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
allow concise mapping of endpoint to handler.

```ruby
router = Coach::Router.new(Example::Application)

router.draw(Routes::Users,
            base: "/users",
            actions: [
              :index,
              :show,
              :create,
              :update,
              disable: { method: :post, url: "/:id/actions/disable" }
            ])
```

Default actions that conform to standard REST principles can be easily loaded, with the
users resource being mapped to...

| Method | URL                          | Description                                    |
|--------|------------------------------|------------------------------------------------|
| `GET`  | `/users`                     | Index all users                                |
| `GET`  | `/users/:id`                 | Get user by ID                                 |
| `POST` | `/users`                     | Create new user                                |
| `PUT`  | `/users/:id`                 | Update user details                            |
| `POST` | `/users/:id/actions/disable` | Custom action routed to the given path suffix  |

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
| `coach.handler.start`     | `event(:middleware, :request)`                         |
| `coach.middleware.start`  | `event(:middleware, :request)`                         |
| `coach.middleware.finish` | `start`, `finish`, `id`, `event(:middleware, :request)`|
| `coach.handler.finish`    | `start`, `finish`, `id`, `event(:middleware, :request)`|
| `coach.request`           | `event` containing request data and benchmarking       |

Of special interest is `coach.request`, which publishes statistics on an entire
middleware chain and request. This data is particularly useful for logging, and is our
solution to Rails `process_action.action_controller` event emitted on controller requests.

The benchmarking data includes information on how long each middleware took to process,
along with the total duration of the chain.
