require "spec_helper"
require "active_support/core_ext/object/try"
require "coach/request_serializer"

describe Coach::RequestSerializer do
  describe ".apply_header_rule" do
    before { described_class.clear_header_rules! }

    let(:header) { "http_abc" }
    let(:rule) { nil }

    context "with header that has a rule that" do
      before { described_class.sanitize_header(header, &rule) }

      context "does not specify block" do
        it "replaces blacklisted header with default text" do
          sanitized = described_class.apply_header_rule(header, "value")
          expect(sanitized).to_not eq("value")
        end
      end

      context "specifies custom block" do
        let(:rule) { ->(value) { "#{value}#{value}" } }

        it "uses block to compute new filtered value" do
          sanitized = described_class.apply_header_rule(header, "value")
          expect(sanitized).to eq("valuevalue")
        end
      end
    end

    context "with header that has no blacklist rule" do
      it "does not modify value" do
        sanitized = described_class.apply_header_rule(header, "value")
        expect(sanitized).to eq("value")
      end
    end

    context "as an instance" do
      subject(:request_serializer) { described_class.new(mock_request) }

      let(:mock_request) do
        instance_double("ActionDispatch::Request", format: nil,
                                                   remote_ip: nil,
                                                   uuid: nil,
                                                   method: nil,
                                                   filtered_parameters: nil,
                                                   filtered_env: {
                                                     "foo" => "bar",
                                                     "HTTP_foo" => "bar",
                                                   })
      end

      describe "#serialize" do
        subject(:serialized) { request_serializer.serialize }

        it "rescues any exceptions request#fullpath may raise" do
          allow(mock_request).to receive(:fullpath).and_raise

          expect(serialized[:path]).to eq("unknown")
        end

        it "filters headers allowing only those prefixed with 'HTTP_'" do
          allow(mock_request).to receive(:fullpath).and_return(nil)

          expect(serialized[:headers]).to_not include("foo")
          expect(serialized[:headers]).to include("http_foo")
        end
      end
    end
  end
end
