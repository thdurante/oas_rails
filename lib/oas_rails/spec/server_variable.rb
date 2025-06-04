module OasRails
  module Spec
    class ServerVariable
      include Specable
      attr_accessor :default, :enum, :description

      def initialize(default:, enum: nil, description: nil)
        @default = default
        @enum = enum
        @description = description
      end

      def oas_fields
        [:default, :enum, :description]
      end
    end
  end
end
