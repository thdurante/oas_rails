module OasRails
  module Spec
    module Specable
      def oas_fields
        []
      end

      def to_spec
        hash = {}
        oas_fields.each do |var|
          key = var.to_s

          camel_case_key = key.camelize(:lower).to_sym
          value = send(var)

          processed_value = if value.respond_to?(:to_spec)
                              value.to_spec
                            elsif value.is_a?(Array) && value.all? { |elem| elem.respond_to?(:to_spec) }
                              value.map(&:to_spec)
                            elsif value.is_a?(Hash)
                              processed_hash = {}
                              value.each do |hash_key, object|
                                processed_hash[hash_key] = if object.respond_to?(:to_spec)
                                                             object.to_spec
                                                           else
                                                             object
                                                           end
                              end
                              processed_hash
                            else
                              value
                            end

          hash[camel_case_key] = processed_value unless valid_processed_value?(processed_value)
        end
        hash
      end

      # rubocop:disable Lint/UnusedMethodArgument
      def as_json(options = nil)
        to_spec
      end
      # rubocop:enable Lint/UnusedMethodArgument

      private

      def valid_processed_value?(processed_value)
        ((processed_value.is_a?(Hash) || processed_value.is_a?(Array)) && processed_value.empty?) || processed_value.nil?
      end

      def snake_to_camel(snake_str)
        words = snake_str.to_s.split('_')
        words[1..].map!(&:capitalize)
        (words[0] + words[1..].join).to_sym
      end
    end
  end
end
