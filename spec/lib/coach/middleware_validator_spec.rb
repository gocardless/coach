require "spec_helper"
require "coach/middleware_validator"

describe Coach::MiddlewareValidator do
  subject(:validator) { described_class.new(head_middleware, already_provided) }

  let(:head_middleware) { build_middleware("Head") }
  let(:already_provided) { [] }

  let(:middleware_a) { build_middleware("A") }
  let(:middleware_b) { build_middleware("B") }
  let(:middleware_c) { build_middleware("C") }

  # head <── a
  #       └─ b <- c
  before do
    head_middleware.uses middleware_a
    head_middleware.uses middleware_b
    middleware_b.uses middleware_c
  end

  describe "#validated_provides!" do
    subject { -> { validator.validated_provides! } }

    context "with satisfied requires" do
      context "one level deep" do
        before do
          head_middleware.requires :a
          middleware_a.provides :a
        end

        it { is_expected.to_not raise_error }
      end

      context "that are inherited up" do
        before do
          head_middleware.requires :c
          middleware_c.provides :c
        end
        it { is_expected.to_not raise_error }
      end

      # Middlewares should be able to use the keys provided by the items `used` before
      # them. In this scenario, terminal will use a then b, and if b requires :a as a key
      # then our dependencies should be satisfied.
      context "that are inherited laterally" do
        before do
          middleware_a.provides :a
          middleware_b.requires :a
        end
        it { is_expected.to_not raise_error }
      end
    end

    context "with missing requirements" do
      context "at terminal" do
        before { head_middleware.requires :a, :c }

        it { is_expected.to raise_exception(/missing \[:a, :c\]/) }
      end

      context "from unordered middleware" do
        before do
          middleware_a.requires :b
          middleware_b.provides :b
        end

        it { is_expected.to raise_exception(/missing \[:b\]/) }
      end
    end
  end
end
