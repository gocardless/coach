# frozen_string_literal: true
require "coach/errors"

module Coach
  class Handler
    def initialize(middleware, config = {})
      @root_item = MiddlewareItem.new(middleware, config)
      validate!
    rescue Coach::Errors::MiddlewareDependencyNotMet => error
      # Remove noise of validation stack trace, reset to the handler callsite
      error.backtrace.clear.concat(Thread.current.backtrace)
      raise error
    end

    # Run validation on the root of the middleware chain
    delegate :validate!, to: :@root_item

    # The Rack interface to handler - builds a middleware chain based on
    # the current request, and invokes it.
    def call(env)
      context = { request: ActionDispatch::Request.new(env) }
      sequence = build_sequence(@root_item, context)
      chain = build_request_chain(sequence, context)

      start_event = start_event(context)
      start = Time.now

      publish('coach.handler.start', start_event.dup)
      response = chain.instrument.call

      finish = Time.now
      publish('coach.handler.finish',
              start, finish, nil,
              start_event.
                merge(response: { status: response[0] },
                      metadata: context.fetch(:_metadata, {})))

      response
    end

    # Traverse the middlware tree to build a linear middleware sequence,
    # containing only middlewares that apply to this request.
    def build_sequence(item, context)
      sequence = item.middleware.middleware_dependencies.map do |child_item|
        build_sequence(child_item.set_parent(item), context)
      end

      dedup_sequence([*sequence, item].flatten)
    end

    # Given a middleware sequence, filter out items not applicable to the
    # current request, and set up a chain of instantiated middleware objects,
    # ready to serve a request.
    def build_request_chain(sequence, context)
      sequence.reverse.reduce(nil) do |successor, item|
        item.build_middleware(context, successor)
      end
    end

    def inspect
      "#<Coach::Handler[#{@root_item.middleware.name}]>"
    end

    private

    # Trigger ActiveSupport::Notification
    def publish(name, *args)
      ActiveSupport::Notifications.publish(name, *args)
    end

    # Remove middleware that have been included multiple times with the same
    # config, leaving only the first instance
    def dedup_sequence(sequence)
      sequence.uniq { |item| [item.class, item.middleware, item.config] }
    end

    # Event to send for start of handler
    def start_event(context)
      {
        middleware: @root_item.middleware.name,
        request: context[:request]
      }
    end
  end
end
