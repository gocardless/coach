require "coach/middleware_item"

module Coach
  class Middleware
    def self.uses(middleware, config = {})
      middleware_dependencies << MiddlewareItem.new(middleware, config)
    end

    def self.middleware_dependencies
      @middleware_dependencies ||= []
    end

    def self.provided
      @provided ||= []
    end

    def self.provides(*new_provided)
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
        ActiveSupport::Notifications.
          publish('coach.middleware.start', middleware_event)
        ActiveSupport::Notifications.
          instrument('coach.middleware.finish', middleware_event) { call }
      end
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
        request: request
      }
    end
  end
end
