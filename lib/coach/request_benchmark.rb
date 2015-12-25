module Coach
  # This class is built to aggregate data during the course of the request. It relies on
  # 'coach.middleware.start' and 'coach.middleware.end' events to register the
  # start/end of each middleware element, and thereby calculate running times for each.
  #
  # Coach::Notifications makes use of this class to produce benchmark data for
  # requests.
  class RequestBenchmark
    def initialize(endpoint_name)
      @endpoint_name = endpoint_name
      @events = []
    end

    def notify(name, start, finish)
      event = { name: name, start: start, finish: finish }

      duration_of_children = child_events_for(event).
        inject(0) { |total, e| total + e[:duration] }
      event[:duration] = (finish - start) - duration_of_children

      @events.push(event)
    end

    def complete(start, finish)
      @duration = finish - start
    end

    # Serialize the results of the benchmarking
    def stats
      {
        endpoint_name: @endpoint_name,
        duration: format_ms(@duration),
        chain: sorted_chain.map do |event|
          { name: event[:name], duration: format_ms(event[:duration]) }
        end
      }
    end

    private

    def previous_event
      @events.last
    end

    def child_events_for(parent)
      @events.select do |child|
        parent[:start] < child[:start] && child[:finish] < parent[:finish]
      end
    end

    def sorted_chain
      @events.sort_by { |event| event[:start] }
    end

    def format_ms(duration)
      (1000 * duration).round
    end
  end
end
