# frozen_string_literal: true

require "spec_helper"
require "coach/notifications"

describe Coach::Notifications do
  subject(:notifications) { described_class.instance }
  let(:request) { Rack::MockRequest.env_for("https://example.com:8080/full/path?query=string", {"REMOTE_ADDR" => "10.10.10.10"}) }

  before do
    described_class.unsubscribe!

    # Remove need to fully mock a request object
    allow(Coach::RequestSerializer).
      to receive(:new).
      and_return(instance_double("Coach::RequestSerializer", serialize: {}))

    ActiveSupport::Notifications.subscribe(/\.coach$/) do |name, *_, event|
      events << [name, event]
    end
  end

  # Capture all Coach events
  let(:events) { [] }
  let(:middleware_event) do
    event = events.find { |(name, _)| name == "request.coach" }
    event && event[1]
  end

  # Mock a handler to simulate an endpoint call
  let(:handler) do
    middleware_a = build_middleware("A")
    middleware_b = build_middleware("B")

    middleware_a.uses(middleware_b)

    terminal_middleware = build_middleware("Terminal")
    terminal_middleware.uses(middleware_a)

    Coach::Handler.new(terminal_middleware)
  end

  describe "#subscribe!" do
    before { notifications.subscribe! }

    it "becomes active" do
      expect(notifications.active?).to be(true)
    end

    it "will now send request.coach" do
      handler.call(request)
      expect(middleware_event).to_not be_nil
    end

    describe "request.coach event" do
      before { handler.call(request) }

      it "contains all middleware that have been run" do
        middleware_names = middleware_event[:chain].map { |item| item[:name] }
        expect(middleware_names).to include("Terminal", "A", "B")
      end

      it "includes all logged metadata" do
        expect(middleware_event).
          to include(metadata: { A: true, B: true, Terminal: true })
      end
    end
  end

  describe "#unsubscribe!" do
    it "disables any prior subscriptions" do
      notifications.subscribe!

      handler.call(request)
      expect(events.count { |(name, _)| name == "request.coach" }).
        to eq(1)

      notifications.unsubscribe!

      handler.call(request)
      expect(events.count { |(name, _)| name == "request.coach" }).
        to eq(1)
    end
  end
end
