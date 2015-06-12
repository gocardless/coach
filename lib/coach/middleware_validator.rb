require "coach/errors"

module Coach
  class MiddlewareValidator
    def initialize(middleware, already_provided = [])
      @middleware = middleware
      @already_provided = already_provided
    end

    # Aggregates provided keys from the given middleware, and all the middleware it uses.
    # Can raise at any level assuming a used middleware is missing a required dependency.
    def validated_provides!
      if missing_requirements.any?
        raise Coach::Errors::MiddlewareDependencyNotMet.new(
          @middleware, missing_requirements
        )
      end

      @middleware.provided + provided_by_chain
    end

    private

    def missing_requirements
      @middleware.requirements - provided_by_chain
    end

    def provided_by_chain
      @provided_by_chain ||=
        middleware_dependencies.reduce(@already_provided) do |provided, middleware|
          provided + self.class.new(middleware, provided).validated_provides!
        end.flatten.uniq
    end

    def middleware_dependencies
      @middleware_dependencies ||= @middleware.middleware_dependencies.map(&:middleware)
    end
  end
end
