require 'rspec'
require 'coach/middleware'

# Middleware stubbing ######################################

def build_middleware(name)
  Class.new(Coach::Middleware) do
    # To access `name`, we need to use `define_method` instead of `def`
    define_method(:to_s) { "<Middleware#{name}>" }
    define_method(:name) { name }
    define_singleton_method(:name) { name }

    def call
      config[:callback].call if config.include?(:callback)
      log_metadata(Hash[name.to_sym, true])

      # Build up a list of middleware called, in the order they were called
      if next_middleware
        [name + config.except(:callback).inspect.to_s].concat(next_middleware.call)
      else
        [name]
      end
    end
  end
end

def null_middleware
  double(call: nil)
end

# Response matchers ########################################

RSpec::Matchers.define :respond_with_status do |expected_status|
  match do |middleware|
    @middleware = middleware
    @response = middleware.call
    @response[0] == expected_status
  end

  failure_message do |actual|
    "expected #{@middleware.class.name} to respond with #{expected_status} but got " \
    "#{@response[0]}"
  end
end

RSpec::Matchers.define :respond_with_body_that_matches do |body_regex|
  match do |middleware|
    @response_body = middleware.call.third.join
    @response_body.match(body_regex)
  end

  failure_message do |actual|
    "expected that \"#{@response_body}\" would match #{body_regex}"
  end
end

RSpec::Matchers.define :respond_with_envelope do |envelope, keys = []|
  match do |middleware|
    @response = JSON.parse(middleware.call.third.join)
    expect(@response).to include(envelope.to_s)

    @envelope = @response[envelope.to_s].with_indifferent_access
    expect(@envelope).to match(hash_including(*keys))
  end

  failure_message do |actual|
    "expected that \"#{@response}\" would have envelope \"#{envelope}\" that matches " \
    "hash_including(#{keys})"
  end
end

RSpec::Matchers.define :respond_with_header do |header, value_regex|
  match do |middleware|
    response_headers = middleware.call.second
    @header_value = response_headers[header]
    @header_value.match(value_regex)
  end

  failure_message do |actual|
    "expected #{header} header in response to match #{value_regex} but found " \
    "\"#{@header_value}\""
  end
end

# Chain matchers ###########################################

RSpec::Matchers.define :call_next_middleware do
  match do |middleware|
    @middleware = middleware
    allow(middleware.next_middleware).to receive(:call)
    middleware.call
    begin
      expect(middleware.next_middleware).to have_received(:call)
      true
    rescue RSpec::Expectations::ExpectationNotMetError
      false
    end
  end

  failure_message do
    "expected that \"#{@middleware.class.name}\" would call next middleware"
  end
end

# Provide/Require matchers #################################

RSpec::Matchers.define :provide do |key|
  match do |middleware|
    allow(middleware).to receive(:provide)
    expect(middleware).to receive(:provide).with(hash_including(key)).and_call_original
    middleware.call
    true
  end
end
