# frozen_string_literal: true

require "rspec/its"
require "pry"
require "rack"
require "coach"
require "coach/rspec"
require "opentelemetry/sdk"

Dir[Pathname(__FILE__).dirname.join("support", "**", "*.rb")].
  sort.
  each { |path| require path }


EXPORTER = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
SPAN_PROCESSOR = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(EXPORTER)

OpenTelemetry::SDK.configure do |c|
  c.add_span_processor SPAN_PROCESSOR
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
