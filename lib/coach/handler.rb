# frozen_string_literal: true

require "coach/errors"
require "active_support/core_ext/object/try"

module Coach
  class Handler
    STATUS_CODE_FOR_EXCEPTIONS = 0

    attr_reader :name

    def initialize(middleware, config = {})
      @config = config
      if middleware.is_a?(String)
        @name = middleware
      else
        @middleware = middleware
        @name = middleware.name
        # This triggers validation of the middleware chain, to raise any errors early on.
        root_item
      end
    end

    delegate :publish, :instrument, :notifier, to: ActiveSupport::Notifications

    # The Rack interface to handler - builds a middleware chain based on
    # the current request, and invokes it.
    # rubocop:disable Metrics/MethodLength
    def call(env)
      context = { request: ActionDispatch::Request.new(env) }
      sequence = build_sequence(root_item, context)
      chain = build_request_chain(sequence, context)

      event = build_event(context)

      publish("start_handler.coach", event.dup)
      instrument("finish_handler.coach", event) do
        response = chain.instrument.call
      rescue StandardError => e
        raise
      ensure
        # We want to populate the response and metadata fields after the middleware
        # chain has completed so that the end of the instrumentation can see them. The
        # simplest way to do this is pass the event by reference to ActiveSupport, then
        # modify the hash to contain this detail before the instrumentation completes.
        #
        # This way, the last finish_handler.coach event will have all the details.
        status = response.try(:first) || STATUS_CODE_FOR_EXCEPTIONS
        event.merge!(
          response: {
            status: status,
            exception: e,
          }.compact,
          metadata: context.fetch(:_metadata, {}),
        )
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
      "#<Coach::Handler[#{name}]>"
    end

    private

    attr_reader :config

    def root_item
      @root_item ||= MiddlewareItem.new(middleware, config).tap(&:validate!)
    rescue Coach::Errors::MiddlewareDependencyNotMet => e
      # Remove noise of validation stack trace, reset to the handler callsite
      e.backtrace.clear.concat(Thread.current.backtrace)
      raise e
    end

    def middleware
      @middleware ||= ActiveSupport::Inflector.constantize(name)
    end

    # Remove middleware that have been included multiple times with the same
    # config, leaving only the first instance
    def dedup_sequence(sequence)
      sequence.uniq { |item| [item.class, item.middleware, item.config] }
    end

    # Event to send with notifications
    def build_event(context)
      { middleware: name, request: context[:request] }
    end
  end
end
