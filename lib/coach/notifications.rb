# frozen_string_literal: true

require_relative "request_benchmark"
require_relative "request_serializer"

module Coach
  # By default, Coach will trigger ActiveSupport::Notifications at specific times in a
  # request lifecycle.
  #
  # Notifications is used to coordinate the listening and aggregation of these middleware
  # notifications, while RequestEvent processes the published data.
  #
  # Once a request has completed, Notifications will emit a 'request.coach' event with
  # aggregated request data.
  class Notifications
    # Begin processing/emitting 'request.coach's
    def self.subscribe!
      instance.subscribe!
    end

    # Cease to emit 'request.coach's
    def self.unsubscribe!
      instance.unsubscribe!
    end

    def self.instance
      @instance ||= new
    end

    def subscribe!
      return if active?

      @subscriptions << subscribe("start_handler") do |_, event|
        @benchmarks[event[:request].uuid] = RequestBenchmark.new(event[:middleware])
      end

      @subscriptions << subscribe("finish_middleware") do |_name, start, finish, _, event|
        log_middleware_finish(event, start, finish)
      end

      @subscriptions << subscribe("finish_handler") do |_name, start, finish, _, event|
        log_handler_finish(event, start, finish)
      end
    end

    def unsubscribe!
      return unless active?

      ActiveSupport::Notifications.unsubscribe(@subscriptions.pop) while @subscriptions.any?
      true
    end

    def active?
      @subscriptions.any?
    end

    private_class_method :new

    private

    def initialize
      @benchmarks = {}
      @subscriptions = []
    end

    def subscribe(event, &block)
      ActiveSupport::Notifications.subscribe("#{event}.coach", &block)
    end

    def log_middleware_finish(event, start, finish)
      benchmark_for_request = @benchmarks[event[:request].uuid]
      return unless benchmark_for_request.present?

      benchmark_for_request.notify(event[:middleware], start, finish)
    end

    def log_handler_finish(event, start, finish)
      benchmark = @benchmarks.delete(event[:request].uuid)
      benchmark.complete(start, finish)
      broadcast(event, benchmark)
    end

    # Receives a handler.finish event, with processed benchmark. Publishes to
    # request.coach notification.
    def broadcast(event, benchmark)
      serialized = RequestSerializer.new(event[:request]).serialize.
        merge(benchmark.stats).
        merge(event.slice(:response, :metadata))
      ActiveSupport::Notifications.publish("request.coach", serialized)
    end
  end
end
