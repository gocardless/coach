require "coach/errors"

module Coach
  class MiddlewareValidator
    def initialize(middleware, previous_middlewares = [], already_provided = [])
      @middleware = middleware
      @previous_middlewares = previous_middlewares.clone
      @already_provided = already_provided
    end

    # Aggregates provided keys from the given middleware, and all the middleware it uses.
    # Can raise at any level assuming a used middleware is missing a required dependency.
    def validated_provides!
      if missing_requirements.any?
        raise Coach::Errors::MiddlewareDependencyNotMet.new(
          @middleware, @previous_middlewares, missing_requirements
        )
      end

      @middleware.provided + provided_by_chain
    end

    private

    attr_reader :previous_middlewares

    def missing_requirements
      @middleware.requirements - provided_by_chain
    end

    def provided_by_chain
      @provided_by_chain ||= begin
        initial = [@already_provided, @previous_middlewares]
        middleware_dependencies.reduce(initial) do |(provided, previous), middleware|
          validator = self.class.new(middleware, previous, provided)
          [provided + validator.validated_provides!, previous + [middleware]]
        end.first.flatten.uniq
      end
    end

    def middleware_dependencies
      @middleware_dependencies ||= @middleware.middleware_dependencies.map(&:middleware)
    end
  end
end
