# frozen_string_literal: true

require_relative "handler"
require_relative "errors"

module Coach
  class Router
    ACTION_TRAITS = {
      index: { method: :get },
      show: { method: :get, url: ":id" },
      create: { method: :post },
      update: { method: :put, url: ":id" },
      destroy: { method: :delete, url: ":id" },
    }.each_value(&:freeze).freeze

    def initialize(mapper)
      @mapper = mapper
    end

    def draw(namespace, base: nil, as: nil, constraints: nil, actions: [])
      action_traits(actions).each do |action, traits|
        handler = build_handler(namespace, action)
        match(action_url(base, traits),
              to: handler,
              via: traits[:method],
              as: as,
              constraints: constraints)
      end
    end

    def match(url, **args)
      @mapper.match(url, args)
    end

    private

    def build_handler(namespace, action)
      action_name = camel(action)

      if namespace.is_a?(String)
        route_name = "#{namespace}::#{action_name}"
        Handler.new(route_name)
      else
        # Passing false to const_get prevents it searching ancestors until a
        # match is found. Without this, globally defined constants such as
        # `Process` will be picked up before consts that need to be autoloaded.
        Handler.new(namespace.const_get(action_name, false))
      end
    end

    # Receives an array of symbols that represent actions for which the default traits
    # should be used, and then lastly an optional trait configuration.
    #
    # Example is...
    #
    #   [ :index, :show, { refund: { url: ':id/refund', method: 'post' } } ]
    #
    # ...which will load the default route for `show` and `index`, while also configuring
    # a refund route.
    def action_traits(list_of_actions)
      *list_of_actions, traits = list_of_actions if list_of_actions.last.is_a?(Hash)

      list_of_actions.reduce(traits || {}) do |memo, action|
        trait = ACTION_TRAITS.fetch(action) do
          raise Errors::RouterUnknownDefaultAction, action
        end

        memo.merge(action => trait)
      end
    end

    # Applies trait url to base, removing duplicate /'s
    def action_url(base, traits)
      [base, traits[:url]].compact.join("/").squeeze("/")
    end

    # Turns a snake_case string/symbol into a CamelCase
    def camel(snake_case)
      snake_case.to_s.capitalize.gsub(/_./) { |match| match[1].upcase }
    end
  end
end
