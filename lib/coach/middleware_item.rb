require "coach/errors"
require "coach/middleware_validator"

module Coach
  class MiddlewareItem
    attr_accessor :middleware, :config

    def initialize(middleware, config = {})
      @middleware = middleware
      @config = config
    end

    def build_middleware(context, successor)
      @middleware.
        new(context,
            successor && successor.instrument,
            config_for_successor(successor))
    end

    # Runs validation against the middleware chain, raising if any unmet dependencies are
    # discovered.
    def validate!
      MiddlewareValidator.new(middleware).validated_provides!
    end

    private

    def config_for_successor(successor)
      if lambda_config?
        @config.call(successor && successor.config || {})
      else
        @config.clone
      end
    end

    def lambda_config?
      @config.respond_to?(:call)
    end
  end
end
