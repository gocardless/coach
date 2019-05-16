# frozen_string_literal: true

require "set"

module Coach
  module Cli
    class ProviderFinder
      def initialize(middleware_name, value_name)
        @middleware_name = middleware_name
        @value_name = value_name
      end

      def run
        if Module.const_defined?(@middleware_name)
          middleware = Module.const_get(@middleware_name)
        else
          raise "That middleware doesn't exist!"
        end

        provider_mapping = build_provider_mapping(middleware, Hash.new { Set.new })

        if provider_mapping.key?(@value_name.to_sym)
          providers = provider_mapping[@value_name.to_sym]
        else
          raise "That value isn't provided!"
        end

        puts "Value `#{@value_name}` is provided by:\n\n"
        puts providers.to_a.join("\n")
      end

      def build_provider_mapping(middleware, mapping)
        middleware.provided.each do |p|
          mapping[p] = mapping[p].add(middleware)
        end

        middleware.middleware_dependencies.each do |dep|
          build_provider_mapping(dep.middleware, mapping)
        end

        mapping
      end
    end
  end
end
