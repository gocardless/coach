# frozen_string_literal: true

require "spec_helper"

require "coach/cli/provider_finder"

describe Coach::Cli::ProviderFinder do
  subject(:provider_finder) { described_class.new(middleware_name, value_name) }

  let(:middleware_name) { "" }
  let(:value_name) { "" }

  describe "#find_provider" do
    context "when there is a single provider" do
      let(:middleware_name) { "RequiringMiddleware" }
      let(:value_name) { "provided_value" }

      before do
        stub_const("ProvidingMiddleware", Class.new(Coach::Middleware) do
          provides :provided_value
        end)
        stub_const(middleware_name, Class.new(Coach::Middleware) do
          uses ProvidingMiddleware

          requires :provided_value
        end)
      end

      it "returns the providing middleware" do
        expect(provider_finder.find_provider).to eq %w[ProvidingMiddleware]
      end
    end

    context "when there are multiple providers" do
      let(:middleware_name) { "RequiringMiddleware" }
      let(:value_name) { "provided_value" }

      before do
        stub_const("FirstProvidingMiddleware", Class.new(Coach::Middleware) do
          provides :provided_value
        end)
        stub_const("SecondProvidingMiddleware", Class.new(Coach::Middleware) do
          provides :provided_value
        end)
        stub_const(middleware_name, Class.new(Coach::Middleware) do
          uses FirstProvidingMiddleware
          uses SecondProvidingMiddleware

          requires :provided_value
        end)
      end

      it "returns the providing middleware" do
        expect(provider_finder.find_provider).
          to eq %w[FirstProvidingMiddleware SecondProvidingMiddleware]
      end
    end

    context "when there's an intermediate middleware after the provider" do
      let(:middleware_name) { "RequiringMiddleware" }
      let(:value_name) { "provided_value" }

      before do
        stub_const("ProvidingMiddleware", Class.new(Coach::Middleware) do
          provides :provided_value
        end)
        stub_const("IntermediateMiddleware", Class.new(Coach::Middleware) do
          uses ProvidingMiddleware
        end)
        stub_const(middleware_name, Class.new(Coach::Middleware) do
          uses IntermediateMiddleware

          requires :provided_value
        end)
      end

      it "returns the providing middleware" do
        expect(provider_finder.find_provider).to eq %w[ProvidingMiddleware]
      end
    end

    context "when the middleware can't be found" do
      let(:middleware_name) { "MiddlewareThatDoesntExist" }

      it "raises a MiddlewareNotFoundError" do
        expect { provider_finder.find_provider }.
          to raise_error(Coach::Cli::Errors::MiddlewareNotFoundError)
      end
    end

    context "when the middleware doesn't require the specified value" do
      let(:middleware_name) { "MiddlewareWithoutRequires" }
      let(:value_name) { "value_that_doesnt_exist" }

      before do
        stub_const(middleware_name, Class.new(Coach::Middleware))
      end

      it "raises a ValueNotRequiredError" do
        expect { provider_finder.find_provider }.
          to raise_error(Coach::Cli::Errors::ValueNotRequiredError)
      end
    end

    context "when the middleware isn't provided with a value it requires" do
      let(:middleware_name) { "MiddlewareWithMissingProvide" }
      let(:value_name) { "value_that_isnt_provided" }

      before do
        stub_const(middleware_name, Class.new(Coach::Middleware) do
          requires :value_that_isnt_provided
        end)
      end

      it "raises a ValueNotProvidedError" do
        expect { provider_finder.find_provider }.
          to raise_error(Coach::Cli::Errors::ValueNotProvidedError)
      end
    end
  end
end
