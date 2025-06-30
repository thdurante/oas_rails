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
      OasRails.config.cache_store = :rails_cache
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

    def test_build_with_rails_cache_enabled
      OasRails.config.enable_caching = true
      OasRails.config.cache_store = :rails_cache

      # First build should cache the result
      spec1 = OasRails.build
      assert OasRails.cached?

      # Second build should return cached result
      spec2 = OasRails.build

      assert_equal spec1, spec2
    end

    def test_build_with_memory_cache_enabled
      OasRails.config.enable_caching = true
      OasRails.config.cache_store = :memory

      # First build should cache the result
      spec1 = OasRails.build
      assert OasRails.cached?

      # Second build should return cached result
      spec2 = OasRails.build

      assert_equal spec1, spec2
    end

    def test_cache_key_generation_with_request
      # Ensure we're using the default cache key generator
      OasRails.config.cache_key_generator = nil

      request = Minitest::Mock.new
      request.expect(:host, "api.example.com")

      key1 = OasRails.send(:generate_cache_key, request)
      key2 = OasRails.send(:generate_cache_key, nil)

      assert_includes key1, "api_example_com"
      assert_includes key2, "default"

      request.verify
    end

    def test_clear_cache_functionality
      OasRails.config.enable_caching = true

      # Build and cache a spec
      OasRails.build
      assert OasRails.cached?

      # Clear cache
      OasRails.clear_cache!
      refute OasRails.cached?
    end

    def test_cache_expiration_with_memory_store
      OasRails.config.enable_caching = true
      OasRails.config.cache_store = :memory
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
      # Ensure we're using the default cache key generator
      OasRails.config.cache_key_generator = nil
      OasRails.config.enable_caching = true

      # Build with default config
      key1 = OasRails.send(:generate_cache_key, nil)

      # Change configuration
      OasRails.config.api_path = "/api/v1"
      key2 = OasRails.send(:generate_cache_key, nil)

      refute_equal key1, key2
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

    def test_memcache_config_configuration
      assert_nil OasRails.config.memcache_config

      # Test with hash configuration
      memcache_config = {
        host: "cache.example.com",
        namespace: "test",
        pool_size: 5
      }
      OasRails.config.memcache_config = memcache_config
      assert_equal memcache_config, OasRails.config.memcache_config

      # Test with proc configuration
      memcache_proc = -> { { host: "dynamic.cache.com", namespace: "dynamic" } }
      OasRails.config.memcache_config = memcache_proc
      assert_equal memcache_proc, OasRails.config.memcache_config
    end

    def test_clear_cache_with_unsupported_cache_store_provides_helpful_error
      # Create a dummy cache class that doesn't support delete_matched
      unsupported_cache_class = Class.new(ActiveSupport::Cache::Store) do
        def respond_to?(method_name, include_private = false)
          return false if method_name == :delete_matched

          super
        end

        def self.name
          "UnsupportedCacheStore"
        end
      end

      unsupported_cache = unsupported_cache_class.new

      Rails.stub :cache, unsupported_cache do
        OasRails.config.cache_store = :rails_cache
        OasRails.config.memcache_config = nil

        error = assert_raises(NotImplementedError) do
          OasRails.clear_cache!
        end

        assert_includes error.message, "For MemCacheStore, provide memcache_config"
        assert_includes error.message, "does not support pattern-based cache clearing"
      end
    end
  end
end
