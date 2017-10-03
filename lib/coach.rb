require "active_support"
require "action_dispatch"

require_relative "coach/errors"
require_relative "coach/handler"
require_relative "coach/middleware"
require_relative "coach/middleware_item"
require_relative "coach/middleware_validator"
require_relative "coach/notifications"
require_relative "coach/request_benchmark"
require_relative "coach/request_serializer"
require_relative "coach/router"
require_relative "coach/version"

module Coach
  def self.require_matchers!
    puts "Calling Coach.require_matchers! is deprecated, " \
         "please use `require 'coach/rspec'` instead"
    require_relative "coach/rspec"
  end
end
