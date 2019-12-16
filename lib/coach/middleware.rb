# frozen_string_literal: true

require "coach/middleware_item"

module Coach
  class Middleware
    def self.uses(middleware, config = {}, &block)
      middleware_dependencies << MiddlewareItem.new(middleware, config, &block)
    end

    def self.middleware_dependencies
      @middleware_dependencies ||= []
    end

    def self.provided
      @provided ||= []
    end

    def self.provides(*new_provided)
      if new_provided.include?(:_metadata)
        raise "Cannot provide :_metadata, Coach uses this internally!"
      end

      provided.concat(new_provided)
      provided.uniq!
    end

    def self.provides?(requirement)
      provided.include?(requirement)
    end

    def self.requirements
      @requirements ||= []
    end

    def self.requires(*new_requirements)
      requirements.concat(new_requirements)
      requirements.uniq!

      new_requirements.each do |requirement|
        define_method(requirement) { @_context[requirement] }
      end
    end

    def self.requires?(provision)
      requirements.include?(provision)
    end

    attr_reader :next_middleware, :config

    # Middleware gets access to a shared context, which is populated by other
    # middleware futher up the stack, a reference to the next middleware in
    # the stack, and a config object.
    def initialize(context, next_middleware = nil, config = {})
      @_context = context
      @next_middleware = next_middleware
      @config = config
    end

    # `request` is always present in context, and we want to give every
    # middleware access to it by default as it's always present and often used!
    def request
      @_context[:request]
    end

    # Make values available to middleware further down the stack. Accepts a
    # hash of name => value pairs. Names must have been declared by calling
    # `provides` on the class.
    def provide(args)
      args.each do |name, value|
        unless self.class.provides?(name)
          raise NameError, "#{self.class} does not provide #{name}"
        end

        @_context[name] = value
      end
    end

    # Use ActiveSupport to instrument the execution of the subsequent chain.
    def instrument
      proc do
        ActiveSupport::Notifications.publish("start_middleware.coach", middleware_event)

        ActiveSupport::Notifications.
          instrument("finish_middleware.coach", middleware_event) { call }
      end
    end

    # Adds key-values to metadata, to be published with coach events.
    def log_metadata(**values)
      @_context[:_metadata] ||= {}
      @_context[:_metadata].merge!(values)
    end

    # Helper to access request params from within middleware
    delegate :params, to: :request

    # Most of the time this will be overridden, but by default we just call
    # the next middleware in the chain.
    delegate :call, to: :next_middleware

    private

    # Event for ActiveSupport
    def middleware_event
      {
        middleware: self.class.name,
        request: request,
      }
    end
  end
end
