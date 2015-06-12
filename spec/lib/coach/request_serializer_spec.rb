require 'spec_helper'
require 'coach/request_serializer'

describe Coach::RequestSerializer do
  describe '.apply_header_rule' do
    before { described_class.clear_header_rules! }

    let(:header) { 'http_abc' }
    let(:rule) { nil }

    context "with header that has a rule that" do
      before { described_class.sanitize_header(header, &rule) }

      context "does not specify block" do
        it "replaces blacklisted header with default text" do
          sanitized = Coach::RequestSerializer.apply_header_rule(header, 'value')
          expect(sanitized).not_to eq('value')
        end
      end

      context "specifies custom block" do
        let(:rule) { ->(value) { "#{value}#{value}" } }

        it "uses block to compute new filtered value" do
          sanitized = Coach::RequestSerializer.apply_header_rule(header, 'value')
          expect(sanitized).to eq('valuevalue')
        end
      end
    end

    context "with header that has no blacklist rule" do
      it "does not modify value" do
        sanitized = Coach::RequestSerializer.apply_header_rule(header, 'value')
        expect(sanitized).to eq('value')
      end
    end
  end
end
