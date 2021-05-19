# frozen_string_literal: true

require "coach/middleware"

describe Coach::Middleware do
  let(:middleware_class) { Class.new(described_class) }
  let(:context_) { {} }
  let(:middleware_obj) { middleware_class.new(context_, nil) }

  describe ".provides" do
    it "blows up if providing a reserved keyword" do
      expect { middleware_class.provides(:_metadata) }.
        to raise_exception(/cannot provide.* coach uses this/i)
    end
  end

  describe ".provides?" do
    context "given names it does provide" do
      before { middleware_class.provides(:foo, :bar) }

      it "returns true" do
        # rubocop:disable RSpec/PredicateMatcher
        expect(middleware_class.provides?(:foo)).to be_truthy
        expect(middleware_class.provides?(:bar)).to be_truthy
        # rubocop:enable RSpec/PredicateMatcher
      end
    end

    context "given names it doesn't provide" do
      before { middleware_class.provides(:foo) }

      it "returns false" do
        # rubocop:disable RSpec/PredicateMatcher
        expect(middleware_class.provides?(:baz)).to be_falsy
        # rubocop:enable RSpec/PredicateMatcher
      end
    end
  end

  describe ".requires?" do
    context "given names it does require" do
      before { middleware_class.requires(:foo, :bar) }

      it "returns true" do
        # rubocop:disable RSpec/PredicateMatcher
        expect(middleware_class.requires?(:foo)).to be_truthy
        expect(middleware_class.requires?(:bar)).to be_truthy
        # rubocop:enable RSpec/PredicateMatcher
      end
    end

    context "given names it doesn't require" do
      before { middleware_class.requires(:foo) }

      it "returns false" do
        # rubocop:disable RSpec/PredicateMatcher
        expect(middleware_class.requires?(:bar)).to be_falsy
        # rubocop:enable RSpec/PredicateMatcher
      end
    end
  end

  describe "#provide" do
    before { middleware_class.provides(:foo) }

    context "given a name it can provide" do
      it "adds it to the context" do
        expect { middleware_obj.provide(foo: "bar") }.
          to change { context_ }.from({}).to(foo: "bar")
      end
    end

    context "given a name it can't provide" do
      it "blows up" do
        expect { middleware_obj.provide(baz: "bar") }.to raise_error(NameError)
      end
    end
  end

  describe "#attributes" do
    before { middleware_class.provides(:foo) }

    context "context is initialized and assigned" do
      it "checks alias of context to _context" do
        expect(middleware_obj.context).to eq(context_)
      end

      it "assigns to context" do
        expect { middleware_obj.provide(foo: "bar") }.
          to change(middleware_obj, :context).from({}).to(foo: "bar")
      end
    end
  end
end
