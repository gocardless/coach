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
      @middleware.new(context, successor && successor.instrument, @config)
    end

    # Requires tweaking to make it run methods by symbol on the class from which the
    # `uses` call is made.
    def use_with_context?(context)
      return true if @config[:if].nil?
      return @config[:if].call(context) if @config[:if].respond_to?(:call)
      middleware.send(@config[:if], context)
    end

    # Runs validation against the middleware chain, raising if any unmet dependencies are
    # discovered.
    def validate!
      MiddlewareValidator.new(middleware).validated_provides!
    end
  end
end
