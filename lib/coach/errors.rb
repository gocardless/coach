module Coach
  module Errors
    class MiddlewareDependencyNotMet < StandardError
      def initialize(middleware, keys)
        super("#{middleware.name} requires keys [#{keys.join(',')}] that are not " \
              "provided by the middleware chain")
      end
    end

    class RouterUnknownDefaultAction < StandardError
      def initialize(action)
        super("Coach::Router does not know how to build action :#{action}")
      end
    end
  end
end
