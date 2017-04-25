# frozen_string_literal: true
require 'spec_helper'
require 'coach/notifications'

describe Coach::Notifications do
  subject(:notifications) { described_class.instance }
  before { described_class.unsubscribe! }

  # Remove need to fully mock a request object
  before do
    allow(Coach::RequestSerializer).
      to receive(:new).and_return(double(serialize: {}))
  end

  # Capture all Coach events
  let(:events) { [] }
  let(:middleware_event) do
    event = events.find { |(name, _)| name == 'coach.request' }
    event && event[1]
  end
  before do
    ActiveSupport::Notifications.subscribe(/coach/) do |name, *_, event|
      events << [name, event]
    end
  end

  # Mock a handler to simulate an endpoint call
  let(:handler) do
    middleware_a = build_middleware('A')
    middleware_b = build_middleware('B')

    middleware_a.uses(middleware_b)

    terminal_middleware = build_middleware('Terminal')
    terminal_middleware.uses(middleware_a)

    Coach::Handler.new(terminal_middleware)
  end

  describe "#subscribe!" do
    before { notifications.subscribe! }

    it "becomes active" do
      expect(notifications.active?).to be(true)
    end

    it "will now send coach.request" do
      handler.call({})
      expect(middleware_event).not_to be_nil
    end

    describe "coach.request event" do
      before { handler.call({}) }

      it "contains all middleware that have been run" do
        middleware_names = middleware_event[:chain].map { |item| item[:name] }
        expect(middleware_names).to include(*%w(Terminal A B))
      end

      it "includes all logged metadata" do
        expect(middleware_event).
          to include(metadata: { A: true, B: true, Terminal: true })
      end
    end
  end

  describe "#unsubscribe!" do
    it "should disable any prior subscriptions" do
      notifications.subscribe!

      handler.call({})
      expect(events.count { |(name, _)| name == 'coach.request' }).
        to eq(1)

      notifications.unsubscribe!

      handler.call({})
      expect(events.count { |(name, _)| name == 'coach.request' }).
        to eq(1)
    end
  end
end
