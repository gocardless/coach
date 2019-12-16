# frozen_string_literal: true

require "coach/errors"
require "coach/middleware_validator"

module Coach
  class MiddlewareItem
    attr_accessor :middleware, :parent

    def initialize(middleware, config = {})
      @middleware = middleware
      @config_value = config
      @block = Proc.new if block_given?
    end

    def build_middleware(context, successor)
      @middleware.
        new(context,
            successor&.instrument,
            config,
            &@block)
    end

    # Runs validation against the middleware chain, raising if any unmet dependencies are
    # discovered.
    def validate!
      MiddlewareValidator.new(middleware).validated_provides!
    end

    # Assigns the parent for this middleware, allowing config inheritance
    # rubocop:disable Naming/AccessorMethodName
    def set_parent(parent)
      @parent = parent

      self
    end
    # rubocop:enable Naming/AccessorMethodName

    # Generates config by either cloning our given config (if it's a hash) else if a
    # lambda value, then will compute the config by calling the lambda with this
    # middlewares parent config.
    def config
      @config ||= lambda_config? ? @config_value.call(parent.config) : @config_value.clone
    end

    private

    def lambda_config?
      @config_value.respond_to?(:call)
    end
  end
end
