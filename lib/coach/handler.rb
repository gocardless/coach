# frozen_string_literal: true

require "coach/errors"
require "active_support/core_ext/object/try"

module Coach
  class Handler
    STATUS_CODE_FOR_EXCEPTIONS = 500

    def initialize(middleware, config = {})
      @root_item = MiddlewareItem.new(middleware, config)
      validate!
    rescue Coach::Errors::MiddlewareDependencyNotMet => e
      # Remove noise of validation stack trace, reset to the handler callsite
      e.backtrace.clear.concat(Thread.current.backtrace)
      raise e
    end

    # Run validation on the root of the middleware chain
    delegate :validate!, to: :@root_item
    delegate :publish, :instrument, :notifier, to: ActiveSupport::Notifications

    # The Rack interface to handler - builds a middleware chain based on
    # the current request, and invokes it.
    # rubocop:disable Metrics/MethodLength
    def call(env)
      context = { request: ActionDispatch::Request.new(env) }
      sequence = build_sequence(@root_item, context)
      chain = build_request_chain(sequence, context)

      event = build_event(context)

      publish("start_handler.coach", event.dup)
      instrument("finish_handler.coach", event) do
        begin
          response = chain.instrument.call
        ensure
          # We want to populate the response and metadata fields after the middleware
          # chain has completed so that the end of the instrumentation can see them. The
          # simplest way to do this is pass the event by reference to ActiveSupport, then
          # modify the hash to contain this detail before the instrumentation completes.
          #
          # This way, the last finish_handler.coach event will have all the details.
          status = response.try(:first) || STATUS_CODE_FOR_EXCEPTIONS
          event.merge!(
            response: { status: status },
            metadata: context.fetch(:_metadata, {}),
          )
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

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

    # Remove middleware that have been included multiple times with the same
    # config, leaving only the first instance
    def dedup_sequence(sequence)
      sequence.uniq { |item| [item.class, item.middleware, item.config] }
    end

    # Event to send with notifications
    def build_event(context)
      {
        middleware: @root_item.middleware.name,
        request: context[:request],
      }
    end
  end
end
