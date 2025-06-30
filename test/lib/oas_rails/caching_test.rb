require "test_helper"

module OasRails
  class CachingTest < Minitest::Test
    def setup
      # Store original cache configuration
      @original_cache_store = Rails.cache
      @original_perform_caching = Rails.application.config.action_controller.perform_caching

      # Enable caching for testing
      Rails.application.config.action_controller.perform_caching = true
      Rails.cache = ActiveSupport::Cache::MemoryStore.new

      # Reset caching configuration to defaults
      OasRails.config.enable_caching = false
      OasRails.config.cache_ttl = 1.hour
      OasRails.config.cache_key_generator = nil
      OasRails.config.cache_debug = false
      OasRails.clear_cache!
    end

    def teardown
      # Restore original cache configuration
      Rails.cache = @original_cache_store
      Rails.application.config.action_controller.perform_caching = @original_perform_caching

      # Clean up after tests
      OasRails.config.enable_caching = false
      OasRails.config.cache_key_generator = nil
      OasRails.config.cache_debug = false
      OasRails.clear_cache!
    end

    def test_caching_disabled_by_default
      refute OasRails.config.enable_caching
    end

    def test_build_without_caching
      # Build spec twice to ensure it's built fresh each time
      spec1 = OasRails.build
      spec2 = OasRails.build

      # Should not be cached
      refute OasRails.cached?

      # Both specs should be built (not from cache)
      assert_kind_of Hash, spec1
      assert_kind_of Hash, spec2
    end

    def test_build_with_caching_enabled
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }

      # First build should cache the result
      spec1 = OasRails.build
      assert OasRails.cached?

      # Second build should return cached result
      spec2 = OasRails.build

      assert_equal spec1, spec2
    end

    def test_cache_key_generation_with_request
      OasRails.config.cache_key_generator = lambda { |request, config|
        "oas_spec_#{request&.host || 'default'}_#{config.include_mode}"
      }

      request = Minitest::Mock.new
      request.expect(:host, "api.example.com")

      key1 = OasRails.send(:generate_cache_key, request)
      key2 = OasRails.send(:generate_cache_key, nil)

      assert_equal "oas_spec_api.example.com_all", key1
      assert_equal "oas_spec_default_all", key2

      request.verify
    end

    def test_clear_cache_functionality
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }

      # Build and cache a spec
      OasRails.build
      assert OasRails.cached?

      # Clear cache
      OasRails.clear_cache!
      refute OasRails.cached?
    end

    def test_cache_expiration_with_ttl
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }
      OasRails.config.cache_ttl = 1.second

      # Build and cache a spec
      spec1 = OasRails.build
      assert OasRails.cached?

      # Wait for cache to expire
      sleep(1.1)

      # Should no longer be cached
      refute OasRails.cached?

      # Should build fresh spec
      spec2 = OasRails.build
      assert_kind_of Hash, spec2
    end

    def test_different_cache_keys_for_different_configurations
      OasRails.config.cache_key_generator = lambda { |request, config|
        "oas_spec_#{config.api_path}_#{config.include_mode}"
      }
      OasRails.config.enable_caching = true

      # Build with default config
      key1 = OasRails.send(:generate_cache_key, nil)

      # Change configuration
      OasRails.config.api_path = "/api/v1"
      key2 = OasRails.send(:generate_cache_key, nil)

      refute_equal key1, key2
      assert_equal "oas_spec_/_all", key1
      assert_equal "oas_spec_/api/v1_all", key2
    end

    def test_custom_cache_key_generator
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = lambda { |request, config|
        "custom_key_#{request&.host || 'default'}_#{config.include_mode}"
      }

      # Mock request
      request = Minitest::Mock.new
      request.expect(:host, "api.example.com")

      key1 = OasRails.send(:generate_cache_key, request)
      key2 = OasRails.send(:generate_cache_key, nil)

      assert_equal "custom_key_api.example.com_all", key1
      assert_equal "custom_key_default_all", key2

      request.verify
    end

    def test_cache_debug_configuration
      refute OasRails.config.cache_debug

      OasRails.config.cache_debug = true
      assert OasRails.config.cache_debug
    end

    def test_custom_cache_key_generator_configuration
      assert_nil OasRails.config.cache_key_generator

      generator = ->(request, config) { "test_key" }
      OasRails.config.cache_key_generator = generator
      assert_equal generator, OasRails.config.cache_key_generator
    end

    def test_cache_key_generator_is_required_when_caching_enabled
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = nil

      # Should raise error when cache_key_generator is not provided
      error = assert_raises(ArgumentError) do
        OasRails.build
      end

      assert_includes error.message, "cache_key_generator must be provided when caching is enabled"
    end

    def test_clear_cache_works_with_any_cache_store
      # Create a custom cache store
      custom_cache_class = Class.new(ActiveSupport::Cache::Store) do
        def initialize
          @data = {}
        end

        def read(key, options = nil)
          @data[key]
        end

        def write(key, value, options = nil)
          @data[key] = value
          true
        end

        def delete(key, options = nil)
          !!@data.delete(key)
        end

        def exist?(key, options = nil)
          @data.key?(key)
        end

        def fetch(key, options = nil)
          if @data.key?(key)
            @data[key]
          else
            value = yield if block_given?
            @data[key] = value if value
            value
          end
        end
      end

      custom_cache = custom_cache_class.new

      Rails.stub :cache, custom_cache do
        OasRails.config.enable_caching = true
        OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }

        # Build and cache a spec
        OasRails.build
        assert OasRails.cached?

        # Clear cache should work with any cache store
        OasRails.clear_cache!

        # Verify cache was cleared
        refute OasRails.cached?
      end
    end
  end
end
