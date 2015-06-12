require "spec_helper"

require "coach/handler"
require "coach/middleware"
require "coach/errors"

describe Coach::Handler do
  let(:middleware_a) { build_middleware("A") }
  let(:middleware_b) { build_middleware("B") }
  let(:middleware_c) { build_middleware("C") }

  let(:terminal_middleware) { build_middleware("Terminal") }
  let(:handler) { Coach::Handler.new(terminal_middleware) }

  before { Coach::Notifications.unsubscribe! }

  describe "#call" do
    let(:a_spy) { spy('middleware a') }
    let(:b_spy) { spy('middleware b') }

    before { terminal_middleware.uses(middleware_a, callback: a_spy) }
    before { terminal_middleware.uses(middleware_b, callback: b_spy) }

    it "invokes all middleware in the chain" do
      result = handler.call({})
      expect(a_spy).to have_received(:call)
      expect(b_spy).to have_received(:call)
      expect(result).to eq(%w(A B Terminal))
    end
  end

  describe "#build_sequence" do
    subject(:sequence) do
      root_item = Coach::MiddlewareItem.new(terminal_middleware)
      handler.build_sequence(root_item, {}).map(&:middleware)
    end

    context "given a route that includes simple middleware" do
      before { terminal_middleware.uses(middleware_a) }

      it "assembles a sequence including all middleware" do
        expect(sequence).to match_array([middleware_a, terminal_middleware])
      end
    end

    context "given a route that includes nested middleware" do
      before { middleware_b.uses(middleware_c) }
      before { middleware_a.uses(middleware_b) }
      before { terminal_middleware.uses(middleware_a) }

      it "assembles a sequence including all middleware" do
        expect(sequence).to match_array([middleware_c, middleware_b,
                                         middleware_a, terminal_middleware])
      end
    end

    context "when a middleware has been included more than once" do
      before { middleware_a.uses(middleware_c) }
      before { middleware_b.uses(middleware_c) }
      before { terminal_middleware.uses(middleware_a) }
      before { terminal_middleware.uses(middleware_b) }

      it "only appears once" do
        expect(sequence).to match_array([middleware_c, middleware_a,
                                         middleware_b, terminal_middleware])
      end

      context "with a different config" do
        before { middleware_b.uses(middleware_c, foo: "bar") }

        it "appears more than once" do
          expect(sequence).to match_array([middleware_c, middleware_a,
                                           middleware_c, middleware_b,
                                           terminal_middleware])
        end
      end
    end
  end

  describe "#build_request_chain" do
    before { terminal_middleware.uses(middleware_a) }
    before { terminal_middleware.uses(middleware_b, if: ->(ctx) { false }) }
    before { terminal_middleware.uses(middleware_c) }

    let(:root_item) { Coach::MiddlewareItem.new(terminal_middleware) }
    let(:sequence) { handler.build_sequence(root_item, {}) }

    it "instantiates all matching middleware items in the sequence" do
      expect(middleware_a).to receive(:new)
      expect(middleware_c).to receive(:new)
      expect(terminal_middleware).to receive(:new)
      handler.build_request_chain(sequence, {})
    end

    it "doesn't instantiate non-matching middleware items" do
      expect(middleware_b).not_to receive(:new)
      handler.build_request_chain(sequence, {})
    end

    it "sets up the chain correctly, calling each item in the correct order" do
      expect(handler.build_request_chain(sequence, {}).call).
        to eq(%w(A C Terminal))
    end
  end

  describe "#call" do
    before { terminal_middleware.uses(middleware_a) }

    describe 'notifications' do
      before { Coach::Notifications.subscribe! }

      # Prevent RequestSerializer from erroring due to insufficient request mock
      before do
        allow(Coach::RequestSerializer).
          to receive(:new).
          and_return(double(serialize: {}))
      end

      subject(:coach_events) do
        events = []
        subscription =
          ActiveSupport::Notifications.subscribe(/coach/) do |name, *args|
            events << name
          end

        handler.call({})
        ActiveSupport::Notifications.unsubscribe(subscription)
        events
      end

      it { is_expected.to include('coach.handler.start') }
      it { is_expected.to include('coach.middleware.start') }
      it { is_expected.to include('coach.request') }
      it { is_expected.to include('coach.middleware.finish') }
      it { is_expected.to include('coach.handler.finish') }
    end
  end
end
