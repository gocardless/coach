# frozen_string_literal: true

module Coach
  module Cli
    class Error < StandardError; end

    module Errors
      class MiddlewareNotFoundError < Error
        attr_reader :middleware_name

        def initialize(middleware_name)
          @middleware_name = middleware_name

          super("Middleware #{@middleware_name} not found")
        end
      end

      class ValueNotRequiredError < Error
        attr_reader :value_name

        def initialize(middleware_name, value_name)
          @middleware_name = middleware_name
          @value_name = value_name

          super("Middleware #{@middleware_name} doesn't require value #{value_name}")
        end
      end

      class ValueNotProvidedError < Error
        attr_reader :value_name

        def initialize(middleware_name, value_name)
          @middleware_name = middleware_name
          @value_name = value_name

          super("Middleware #{@middleware_name} isn't provided with value #{value_name}")
        end
      end
    end
  end
end
