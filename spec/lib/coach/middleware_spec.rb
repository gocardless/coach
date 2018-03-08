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
        expect(middleware_class).to be_provides(:foo)
        expect(middleware_class).to be_provides(:bar)
      end
    end

    context "given names it doesn't provide" do
      before { middleware_class.provides(:foo) }

      it "returns false" do
        expect(middleware_class).to_not be_provides(:baz)
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
end
