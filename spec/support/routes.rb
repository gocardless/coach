# frozen_string_literal: true

module Routes
  module Thing
    class Index < Coach::Middleware
      def call
        [200, {}, []]
      end
    end

    class Show < Coach::Middleware
      def call
        [200, {}, []]
      end
    end

    class Create < Coach::Middleware
      def call
        [200, {}, []]
      end
    end

    class Update < Coach::Middleware
      def call
        [200, {}, []]
      end
    end

    class Destroy < Coach::Middleware
      def call
        [200, {}, []]
      end
    end

    class Refund < Coach::Middleware
      def call
        [200, {}, []]
      end
    end
  end
end
