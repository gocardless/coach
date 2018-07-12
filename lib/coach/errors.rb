# frozen_string_literal: true

module Coach
  module Errors
    class MiddlewareDependencyNotMet < StandardError
      def initialize(middleware, previous_chain, missing_keys)
        @middleware = middleware
        @previous_chain = previous_chain
        @missing_keys = missing_keys

        super("\n\n#{chain_diagram}\n\n#{missing_keys_message}\n\n")
      end

      def missing_keys_message
        "  #{@middleware.name} is missing #{@missing_keys} from above!"
      end

      def chain_diagram
        @previous_chain.map do |middleware|
          "  #{middleware.name} => #{middleware.provided}"
        end.join("\n")
      end
    end

    class RouterUnknownDefaultAction < StandardError
      def initialize(action)
        super("Coach::Router does not know how to build action :#{action}")
      end
    end
  end
end
