require "yard"
require "method_source"
require "easy_talk"

module OasRails
  require "oas_rails/version"
  require "oas_rails/engine"

  autoload :Configuration, "oas_rails/configuration"
  autoload :OasRoute, "oas_rails/oas_route"
  autoload :Utils, "oas_rails/utils"
  autoload :JsonSchemaGenerator, "oas_rails/json_schema_generator"
  autoload :ActiveRecordExampleFinder, "oas_rails/active_record_example_finder"

  module Builders
    autoload :OperationBuilder, "oas_rails/builders/operation_builder"
    autoload :PathItemBuilder, "oas_rails/builders/path_item_builder"
    autoload :ResponseBuilder, "oas_rails/builders/response_builder"
    autoload :ResponsesBuilder, "oas_rails/builders/responses_builder"
    autoload :ContentBuilder, "oas_rails/builders/content_builder"
    autoload :ParametersBuilder, "oas_rails/builders/parameters_builder"
    autoload :ParameterBuilder, "oas_rails/builders/parameter_builder"
    autoload :RequestBodyBuilder, "oas_rails/builders/request_body_builder"
    autoload :EsquemaBuilder, "oas_rails/builders/esquema_builder"
    autoload :OasRouteBuilder, "oas_rails/builders/oas_route_builder"
  end

  # This module contains all the clases that represent a part of the OAS file.
  module Spec
    autoload :Hashable, "oas_rails/spec/hashable"
    autoload :Specable, "oas_rails/spec/specable"
    autoload :Components, "oas_rails/spec/components"
    autoload :Parameter, "oas_rails/spec/parameter"
    autoload :License, "oas_rails/spec/license"
    autoload :Response, "oas_rails/spec/response"
    autoload :PathItem, "oas_rails/spec/path_item"
    autoload :Operation, "oas_rails/spec/operation"
    autoload :RequestBody, "oas_rails/spec/request_body"
    autoload :Responses, "oas_rails/spec/responses"
    autoload :MediaType, "oas_rails/spec/media_type"
    autoload :Paths, "oas_rails/spec/paths"
    autoload :Contact, "oas_rails/spec/contact"
    autoload :Info, "oas_rails/spec/info"
    autoload :Server, "oas_rails/spec/server"
    autoload :ServerVariable, "oas_rails/spec/server_variable"
    autoload :Tag, "oas_rails/spec/tag"
    autoload :Specification, "oas_rails/spec/specification"
    autoload :Reference, "oas_rails/spec/reference"
  end

  module YARD
    autoload :RequestBodyTag, 'oas_rails/yard/request_body_tag'
    autoload :ExampleTag, 'oas_rails/yard/example_tag'
    autoload :RequestBodyExampleTag, 'oas_rails/yard/request_body_example_tag'
    autoload :ParameterTag, 'oas_rails/yard/parameter_tag'
    autoload :ResponseTag, 'oas_rails/yard/response_tag'
    autoload :ResponseExampleTag, 'oas_rails/yard/response_example_tag'
    autoload :OasRailsFactory, 'oas_rails/yard/oas_rails_factory'
  end

  module Extractors
    autoload :RenderResponseExtractor, 'oas_rails/extractors/render_response_extractor'
    autoload :RouteExtractor, "oas_rails/extractors/route_extractor"
    autoload :OasRouteExtractor, "oas_rails/extractors/oas_route_extractor"
  end

  class << self
    def build(request: nil)
      # Return cached version if caching is enabled and cache exists
      if config.enable_caching
        cached_spec = fetch_from_cache(request)
        return cached_spec if cached_spec
      end

      # Build the specification
      oas = Spec::Specification.new(request: request)
      oas.build
      spec = oas.to_spec

      # Cache the result if caching is enabled
      store_in_cache(spec, request) if config.enable_caching

      spec
    end

    # Configurations for make the OasRails engine Work.
    def configure
      OasRails.configure_yard!
      yield config
    end

    def config
      @config ||= Configuration.new
    end

    # Clear the OpenAPI specification cache
    def clear_cache!
      case config.cache_store
      when :rails_cache
        if Rails.cache.respond_to?(:delete_matched)
          Rails.cache.delete_matched("oas_rails_spec_*")
        elsif config.memcache_config && Rails.cache.is_a?(ActiveSupport::Cache::MemCacheStore)
          clear_memcache_namespace
        else
          raise NotImplementedError, 
            "Cache store #{Rails.cache.class} does not support pattern-based cache clearing. " \
            "For MemCacheStore, provide memcache_config in your OasRails configuration, " \
            "or consider using a cache store that supports delete_matched (like RedisCacheStore or FileStore), " \
            "or rely on TTL-based cache expiration instead of manual clearing."
        end
      when :memory
        @memory_cache&.clear
      end
    end

    # Check if specification is cached
    def cached?(request: nil)
      return false unless config.enable_caching

      cache_key = generate_cache_key(request)
      case config.cache_store
      when :rails_cache
        Rails.cache.exist?(cache_key)
      when :memory
        @memory_cache ||= {}
        cached_data = @memory_cache[cache_key]
        return false unless cached_data

        # Check if cache has expired
        if cached_data[:expires_at] <= Time.current
          @memory_cache.delete(cache_key)
          return false
        end

        true
      else
        false
      end
    end

    def configure_yard!
      ::YARD::Tags::Library.default_factory = YARD::OasRailsFactory
      yard_tags = {
        'Request body' => [:request_body, :with_request_body],
        'Request body Example' => [:request_body_example, :with_request_body_example],
        'Parameter' => [:parameter, :with_parameter],
        'Response' => [:response, :with_response],
        'Response Example' => [:response_example, :with_response_example],
        'Endpoint Tags' => [:tags],
        'Summary' => [:summary],
        'No Auth' => [:no_auth],
        'Auth methods' => [:auth, :with_types],
        'OAS Include' => [:oas_include]
      }
      yard_tags.each do |tag_name, (method_name, handler)|
        ::YARD::Tags::Library.define_tag(tag_name, method_name, handler)
      end
    end

    private

    def fetch_from_cache(request)
      cache_key = generate_cache_key(request)
      log_cache_debug("Attempting to fetch from cache with key: #{cache_key}") if config.cache_debug

      case config.cache_store
      when :rails_cache
        result = Rails.cache.read(cache_key)
        log_cache_debug("Rails cache #{result ? 'HIT' : 'MISS'} for key: #{cache_key}") if config.cache_debug
        result
      when :memory
        @memory_cache ||= {}
        cached_data = @memory_cache[cache_key]
        return nil unless cached_data

        # Check if cache has expired
        if cached_data[:expires_at] <= Time.current
          @memory_cache.delete(cache_key)
          log_cache_debug("Memory cache EXPIRED for key: #{cache_key}") if config.cache_debug
          return nil
        end

        log_cache_debug("Memory cache HIT for key: #{cache_key}") if config.cache_debug
        cached_data[:data]
      end
    end

    def store_in_cache(spec, request)
      cache_key = generate_cache_key(request)
      log_cache_debug("Storing in cache with key: #{cache_key}, TTL: #{config.cache_ttl}") if config.cache_debug

      case config.cache_store
      when :rails_cache
        success = Rails.cache.write(cache_key, spec, expires_in: config.cache_ttl)
        log_cache_debug("Rails cache write #{success ? 'SUCCESS' : 'FAILED'} for key: #{cache_key}") if config.cache_debug
      when :memory
        @memory_cache ||= {}
        @memory_cache[cache_key] = {
          data: spec,
          expires_at: Time.current + config.cache_ttl
        }
        log_cache_debug("Memory cache write SUCCESS for key: #{cache_key}") if config.cache_debug
      end
    end

    def generate_cache_key(request)
      # Use custom cache key generator if provided
      if config.cache_key_generator.respond_to?(:call)
        custom_key = config.cache_key_generator.call(request, config)
        log_cache_debug("Custom cache key generated: #{custom_key}") if config.cache_debug
        return custom_key
      end
      
      # Generate a cache key based on configuration that affects the spec
      key_components = [
        "oas_rails_spec",
        config.api_path,
        config.include_mode,
        config.ignored_actions.sort.join(","),
        Rails.env,
        # Include request host if available for server-specific caching
        request&.host || "default"
      ]
      generated_key = key_components.join("_").gsub(/[^a-zA-Z0-9_-]/, "_")
      log_cache_debug("Default cache key generated: #{generated_key}") if config.cache_debug
      generated_key
    end

    def clear_memcache_namespace
      memcache_options = if config.memcache_config.respond_to?(:call)
                           config.memcache_config.call
                         else
                           config.memcache_config
                         end

      return unless memcache_options.is_a?(Hash)

      begin
        require 'dalli'
        
        # Create a direct connection to memcache using the provided configuration
        client = Dalli::Client.new(
          memcache_options[:host],
          memcache_options
        )

        # If a namespace is provided, we can flush the entire namespace
        if memcache_options[:namespace]
          # Flush all keys in the namespace by incrementing the namespace version
          # This is the standard way to "flush" a namespace in memcache
          namespace_key = "#{memcache_options[:namespace]}:version"
          current_version = client.get(namespace_key) || 0
          client.set(namespace_key, current_version + 1)
          log_cache_debug("MemCache namespace '#{memcache_options[:namespace]}' cleared by incrementing version to #{current_version + 1}") if config.cache_debug
        else
          log_cache_debug("Warning: No namespace provided in memcache_config. Cannot clear cache efficiently.") if config.cache_debug
        end

        client.close
      rescue LoadError
        raise LoadError, "The 'dalli' gem is required to clear MemCacheStore cache. Add 'gem \"dalli\"' to your Gemfile."
      rescue => e
        log_cache_debug("Failed to clear MemCache: #{e.message}") if config.cache_debug
        raise e
      end
    end

    def log_cache_debug(message)
      Rails.logger.debug("[OasRails Cache] #{message}") if defined?(Rails.logger)
    end
  end
end
