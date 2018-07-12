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

    def draw(routes, base: nil, as: nil, constraints: nil, actions: [])
      action_traits(actions).each do |action, traits|
        # Passing false to const_get prevents it searching ancestors until a
        # match is found. Without this, globally defined constants such as
        # `Process` will be picked up before consts that need to be autoloaded.
        route = routes.const_get(camel(action), false)
        match(action_url(base, traits),
              to: Handler.new(route),
              via: traits[:method],
              as: as,
              constraints: constraints)
      end
    end

    def match(url, **args)
      @mapper.match(url, args)
    end

    private

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
      [base, traits[:url]].compact.join("/").gsub(%r{/+}, "/")
    end

    # Turns a snake_case string/symbol into a CamelCase
    def camel(snake_case)
      snake_case.to_s.capitalize.gsub(/_./) { |match| match[1].upcase }
    end
  end
end
