module OasRails
  module Spec
    class Server
      include Specable
      attr_accessor :url, :description, :variables

      def initialize(url:, description:, variables: nil)
        @url = url
        @description = description
        @variables = process_variables(variables)
      end

      def oas_fields
        [:url, :description, :variables]
      end

      private

      def process_variables(variables)
        return nil if variables.nil? || variables.empty?

        processed = {}
        variables.each do |key, value|
          processed[key] = if value.is_a?(Hash)
                             ServerVariable.new(
                               default: value[:default] || value['default'],
                               enum: value[:enum] || value['enum'],
                               description: value[:description] || value['description']
                             )
                           else
                             value
                           end
        end
        processed
      end
    end
  end
end
