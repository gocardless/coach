require 'spec_helper'

require 'coach/router'
require 'coach/handler'

describe Coach::Router do
  subject(:router) { described_class.new(app) }
  let(:app) { double(:rails_app, routes: double(draw: nil)) }

  before do
    allow(Coach::Handler).to receive(:new) { |route| route }
  end

  let(:resource_routes) do
    Module.new do
      class Index; end
      class Show; end
      class Create; end
      class Update; end
      class Destroy; end
      class Refund; end  # custom
    end
  end

  shared_examples "mount action" do |action, params|
    let(:actions) { [action] }

    it "correctly mounts url for :#{action}" do
      expect(router).to receive(:match).with(params[:url], anything)
      draw
    end

    it "correctly mounts on method for :#{action}" do
      expect(router).to receive(:match).
        with(anything, hash_including(via: params[:method]))
      draw
    end
  end

  describe "#draw" do
    subject(:draw) { router.draw(resource_routes, base: '/resource', actions: actions) }

    context "with default action" do
      it_behaves_like "mount action", :index, url: '/resource', method: :get
      it_behaves_like "mount action", :show, url: '/resource/:id', method: :get
      it_behaves_like "mount action", :create, url: '/resource', method: :post
      it_behaves_like "mount action", :update, url: '/resource/:id', method: :put
      it_behaves_like "mount action", :destroy, url: '/resource/:id', method: :delete
    end

    context "with custom action" do
      let(:actions) { [refund: { method: :post, url: custom_url }] }

      context "with no slash" do
        let(:custom_url) { ':id/refund' }
        it "mounts correct url" do
          expect(router).to receive(:match).with('/resource/:id/refund', anything)
          draw
        end
      end

      context "with multiple /'s" do
        let(:custom_url) { '//:id/refund' }
        it "mounts correct url" do
          expect(router).to receive(:match).with('/resource/:id/refund', anything)
          draw
        end
      end
    end

    context "with unknown default action" do
      let(:actions) { [:unknown] }
      it "raises RouterUnknownDefaultAction" do
        expect { draw }.to raise_error(Coach::Errors::RouterUnknownDefaultAction)
      end
    end
  end
end
