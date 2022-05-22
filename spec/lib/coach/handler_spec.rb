# frozen_string_literal: true

require "spec_helper"

require "coach/handler"
require "coach/middleware"
require "coach/errors"

describe Coach::Handler do
  subject(:handler) { described_class.new(terminal_middleware, handler: true) }


  let(:request) { Rack::MockRequest.env_for("https://example.com:8080/full/path?query=string", {"REMOTE_ADDR" => "10.10.10.10"}) }
  let(:middleware_a) { build_middleware("A") }
  let(:middleware_b) { build_middleware("B") }
  let(:middleware_c) { build_middleware("C") }
  let(:middleware_d) { build_middleware("D") }

  let(:terminal_middleware) { build_middleware("Terminal") }

  before { Coach::Notifications.unsubscribe! }

  describe "#call" do
    context "with multiple middleware" do
      let(:a_double) { double.as_null_object }
      let(:b_double) { double.as_null_object }

      before do
        terminal_middleware.uses(middleware_a, callback: a_double)
        terminal_middleware.uses(middleware_b, callback: b_double)
      end

      it "invokes all middleware in the chain" do
        expect(a_double).to receive(:call)
        expect(b_double).to receive(:call)
        result = handler.call(request)
        expect(result).to eq(%w[A{} B{} Terminal{:handler=>true}])
      end

      context "with an invalid chain" do
        before { terminal_middleware.requires(:not_available) }

        it "raises an error" do
          expect { handler }.to raise_error(Coach::Errors::MiddlewareDependencyNotMet)
        end
      end

      context "lazy-loading the middleware" do
        subject(:handler) { described_class.new(terminal_middleware.name, handler: true) }

        before do
          allow(ActiveSupport::Inflector).to receive(:constantize).and_call_original
          allow(ActiveSupport::Inflector).to receive(:constantize).
            with(terminal_middleware.name).
            and_return(terminal_middleware)
        end

        it "does not load the route when initialized" do
          expect(ActiveSupport::Inflector).
            to_not receive(:constantize).with(terminal_middleware.name)

          handler
        end

        it "calls through the middleware chain" do
          expect(a_double).to receive(:call)
          expect(b_double).to receive(:call)

          result = handler.call(request)

          expect(result).to eq(%w[A{} B{} Terminal{:handler=>true}])
        end

        context "with an invalid chain" do
          before { terminal_middleware.requires(:not_available) }

          it "does not raise on initialize" do
            expect { handler }.to_not raise_error
          end

          it "raises on first call" do
            expect { handler.call(request) }.
              to raise_error(Coach::Errors::MiddlewareDependencyNotMet)
          end
        end
      end
    end

    describe "tracing" do
      let(:exporter) { EXPORTER }
      let(:spans) { exporter.finished_spans }
      let(:handler_span) { spans.find{ |s| s.name == "Coach::Handler Terminal" } }
      let(:parent_span) { spans.find { |s| s.span_id == handler_span.parent_span_id } }

      before do
        exporter.reset
        terminal_middleware.uses(middleware_a)
        handler.call(request)
      end

      it "includes the handler span" do
        expect(spans.size).to eq(3)
        expect(handler_span).to_not be_nil
        expect(parent_span).to be_nil
        expect(handler_span.attributes["http.method"]).to eq("GET")
      end

      it "includes middleware as a child span" do
        child_span = spans.find{ |s| s.parent_span_id == handler_span.span_id }
        expect(child_span).to_not be_nil
        expect(child_span.name).to eq("Coach::Middleware A")
      end
    end

    describe "notifications" do
      subject(:coach_events) do
        events = []
        subscription = ActiveSupport::Notifications.
          subscribe(/\.coach$/) { |name, *_args| events << name }

        handler.call(request)
        ActiveSupport::Notifications.unsubscribe(subscription)
        events
      end

      before do
        terminal_middleware.uses(middleware_a)

        Coach::Notifications.subscribe!

        # Prevent RequestSerializer from erroring due to insufficient request mock
        allow(Coach::RequestSerializer).
          to receive(:new).
          and_return(instance_double("Coach::RequestSerializer", serialize: {}))
      end

      it { is_expected.to include("start_handler.coach") }
      it { is_expected.to include("start_middleware.coach") }
      it { is_expected.to include("request.coach") }
      it { is_expected.to include("finish_middleware.coach") }
      it { is_expected.to include("finish_handler.coach") }

      context "when an exception is raised in the chain" do
        subject(:coach_events) do
          events = []
          subscription = ActiveSupport::Notifications.
            subscribe(/\.coach$/) do |name, *args|
            events << [name, args.last]
          end

          begin
            handler.call(request)
          rescue StandardError
            :continue_anyway
          end
          ActiveSupport::Notifications.unsubscribe(subscription)
          events
        end

        let(:explosive_action) { -> { raise "AH" } }

        before { terminal_middleware.uses(middleware_a, callback: explosive_action) }

        it "captures the error event with the metadata and nil status" do
          expect(coach_events).
            to include(["finish_handler.coach", hash_including(
              response: { status: 0, exception: instance_of(RuntimeError) },
              metadata: { A: true },
            )])
        end

        it "bubbles the error to the next handler" do
          expect { handler.call(request) }.to raise_error(StandardError, "AH")
        end
      end
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
      before do
        middleware_b.uses(middleware_c)
        middleware_a.uses(middleware_b)
        terminal_middleware.uses(middleware_a)
      end

      it "assembles a sequence including all middleware" do
        expect(sequence).to match_array([middleware_c, middleware_b,
                                         middleware_a, terminal_middleware])
      end
    end

    context "when a middleware has been included more than once" do
      before do
        middleware_a.uses(middleware_c)
        middleware_b.uses(middleware_c)
        terminal_middleware.uses(middleware_a)
        terminal_middleware.uses(middleware_b)
      end

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
    before do
      terminal_middleware.uses(middleware_a)
      terminal_middleware.uses(middleware_b, b: true)
    end

    let(:root_item) { Coach::MiddlewareItem.new(terminal_middleware) }
    let(:sequence) { handler.build_sequence(root_item, {}) }

    it "instantiates all matching middleware items in the sequence" do
      expect(middleware_a).to receive(:new)
      expect(middleware_b).to receive(:new)
      expect(terminal_middleware).to receive(:new)
      handler.build_request_chain(sequence, {})
    end

    it "sets up the chain correctly, calling each item in the correct order" do
      expect(handler.build_request_chain(sequence, {}).call).
        to eq(%w[A{} B{:b=>true} Terminal{}])
    end

    context "with inheriting config" do
      before do
        middleware_b.uses(middleware_c, ->(config) { config.slice(:b) })
        middleware_b.uses(middleware_d)
      end

      it "calls lambda with parent middlewares config" do
        expect(handler.build_request_chain(sequence, {}).call).
          to eq(%w[A{} C{:b=>true} D{} B{:b=>true} Terminal{}])
      end
    end
  end

  describe "#inspect" do
    its(:inspect) { is_expected.to eql("#<Coach::Handler[Terminal]>") }
  end
end
