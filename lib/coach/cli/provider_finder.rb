# frozen_string_literal: true

require "coach/cli/errors"
require "set"

module Coach
  module Cli
    class ProviderFinder
      def initialize(middleware_name, value_name)
        @middleware_name = middleware_name
        @value_name = value_name
      end

      def find_provider
        enforce_middleware_exists!
        middleware = Module.const_get(@middleware_name)

        enforce_middleware_requires_value!(middleware)

        provider_mapping = build_provider_mapping(middleware, Hash.new { Set.new })

        if provider_mapping.key?(@value_name.to_sym)
          providers = provider_mapping[@value_name.to_sym]
        else
          err = Errors::ValueNotProvidedError.new(@middleware_name, @value_name)
          raise err
        end

        providers.to_a.map(&:to_s)
      end

      def find_chain
        if Module.const_defined?(@middleware_name)
          middleware = Module.const_get(@middleware_name)
        else
          raise "That middleware doesn't exist!"
        end

        provider_chain = build_provider_chain(middleware, Hash.new { Set.new }, [])

        if provider_chain.key?(@value_name.to_sym)
          chains = provider_chain[@value_name.to_sym]
        else
          raise "That value isn't provided!"
        end

        if chains.size > 1
          puts "Value `#{@value_name}` is provided to `#{@middleware_name}` " \
            "by multiple middleware chains:\n\n"
        else
          puts "Value `#{@value_name}` is provided to `#{@middleware_name}` by:\n\n"
        end

        formatted_chains = chains.map do |chain|
          chain.join(" -> ")
        end.join("\n---\n")

        puts formatted_chains
      end

      private

      def enforce_middleware_exists!
        unless Module.const_defined?(@middleware_name)
          err = Errors::MiddlewareNotFoundError.new(@middleware_name)
          raise err
        end
      end

      def enforce_middleware_requires_value!(middleware)
        unless middleware.requires?(@value_name.to_sym)
          err = Errors::ValueNotRequiredError.new(@middleware_name, @value_name)
          raise err
        end
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

      def build_provider_chain(middleware, mapping, chain)
        new_chain = chain + [middleware]

        middleware.provided.each do |p|
          mapping[p] = mapping[p].add(new_chain)
        end

        middleware.middleware_dependencies.each do |dep|
          build_provider_chain(dep.middleware, mapping, new_chain)
        end

        mapping
      end
    end
  end
end
