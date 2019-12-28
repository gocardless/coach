# frozen_string_literal: true

module Spring
  module Commands
    class Coach
      def env(*)
        "development"
      end

      def exec_name
        "coach"
      end

      Spring.register_command "coach", Coach.new
    end
  end
end
