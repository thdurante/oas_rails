require 'json'

module OasRails
  module Spec
    class Specification
      include Specable
      attr_accessor :components, :info, :openapi, :servers, :tags, :external_docs, :paths

      # Initializes a new Specification object.
      # Clears the cache if running in the development environment.
      def initialize
        clear_cache unless Rails.env.production?

        @components = Components.new(self)
        @info = OasRails.config.info
        @openapi = '3.1.0'
        @servers = OasRails.config.servers
        @tags = OasRails.config.tags
        @external_docs = {}
        @paths = Spec::Paths.new(self)
      end

      def build(route_extractor: Extractors::RouteExtractor)
        route_extractor.host_paths.each do |path|
          @paths.add_path(path)
        end
      end

      # Clears the cache for MethodSource and RouteExtractor.
      #
      # @return [void]
      def clear_cache
        if defined?(MethodSource)
          if MethodSource.respond_to?(:clear_cache)
            MethodSource.clear_cache
          else
            # Ruby 2.7 support
            MethodSource.instance_variable_set(:@source_cache, {})
          end
        end

        Extractors::RouteExtractor.clear_cache
      end

      def oas_fields
        [:openapi, :info, :servers, :paths, :components, :security, :tags, :external_docs]
      end

      # Create the Security Requirement Object.
      # @see https://spec.openapis.org/oas/latest.html#security-requirement-object
      def security
        return [] unless OasRails.config.authenticate_all_routes_by_default

        OasRails.config.security_schemas.map { |key, _| { key => [] } }
      end
    end
  end
end
