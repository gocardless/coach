# frozen_string_literal: true

module Coach
  class RequestSerializer
    # Rack specs dictate that CONTENT_TYPE and CONTENT_LENGTH
    # are not prefixed with HTTP_.
    # See https://rubydoc.info/github/rack/rack/master/file/SPEC
    RACK_UNPREFIXED_HEADERS = %w[CONTENT_TYPE CONTENT_LENGTH].freeze

    def self.header_rules
      @header_rules ||= {}
    end

    # Sets global rules on how to sanitize headers. An optional block can be supplied
    # that will determine how to transform the original header value, otherwise a default
    # string is used.
    def self.sanitize_header(header, &rule)
      header_rules[header] = rule || ->(_value) { "[FILTERED]" }
    end

    # Applies sanitizing rules. Expects `header` to be in 'http_header_name' form.
    def self.apply_header_rule(header, value)
      return value if header_rules[header].nil?

      header_rules[header].call(value)
    end

    # Resets all header sanitizing
    def self.clear_header_rules!
      @header_rules = {}
    end

    def initialize(request)
      @request = request
    end

    def serialize
      {
        # Identification
        request_id: @request.uuid,

        # Request details
        method: @request.method,
        path: request_path,
        format: @request.format.try(:ref),
        params: @request.filtered_parameters, # uses config.filter_parameters

        # Extra request info
        headers: filtered_headers,
        session_id: @request.remote_ip, # TODO: remove in a future release
        session_ip: @request.remote_ip,
      }
    end

    private

    def request_path
      @request.fullpath
    rescue StandardError
      "unknown"
    end

    def filtered_headers
      header_value_pairs = @request.filtered_env.map do |key, value|
        key = if RACK_UNPREFIXED_HEADERS.include?(key)
                "http_#{key.downcase}"
              elsif key =~ /^HTTP_/
                key.downcase
              end

        [key, self.class.apply_header_rule(key, value)] if key
      end.compact

      Hash[header_value_pairs]
    end
  end
end
