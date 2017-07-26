require 'spec_helper'
require 'coach/request_benchmark'

describe Coach::RequestBenchmark do
  subject(:event) { described_class.new('ENDPOINT') }

  let(:base_time) { Time.now }

  let(:start)     { base_time + 0 }
  let(:a_start)   { base_time + 1 }
  let(:b_start)   { base_time + 2 }
  let(:b_finish)  { base_time + 3 }
  let(:a_finish)  { base_time + 4 }
  let(:finish)    { base_time + 5 }

  before do
    event.notify('B', b_start, b_finish)
    event.notify('A', a_start, a_finish)
    event.complete(start, finish)
  end

  describe "#stats" do
    subject(:stats) { event.stats }

    it "computes overall duration" do
      expect(stats[:duration]).to eq(5000)
    end

    it "computes duration of middleware with no children" do
      expect(stats[:chain]).to include(name: 'B', duration: 1000)
    end

    it "adjusts duration of middleware for their children" do
      expect(stats[:chain]).to include(name: 'A', duration: 2000)
    end

    it "correctly orders chain" do
      chain_names = stats[:chain].map { |item| item[:name] }
      expect(chain_names).to eq %w[A B]
    end
  end
end
