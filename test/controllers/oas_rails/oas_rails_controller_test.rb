require "test_helper"

module OasRails
  class OasRailsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    def setup
      @routes = Engine.routes

      # Store original cache configuration
      @original_cache_store = Rails.cache
      @original_perform_caching = Rails.application.config.action_controller.perform_caching

      # Enable caching for testing
      Rails.application.config.action_controller.perform_caching = true
      Rails.cache = ActiveSupport::Cache::MemoryStore.new

      # Reset caching configuration to defaults
      OasRails.config.enable_caching = false
      OasRails.config.cache_ttl = 1.hour
      OasRails.clear_cache!
    end

    def teardown
      # Restore original cache configuration
      Rails.cache = @original_cache_store
      Rails.application.config.action_controller.perform_caching = @original_perform_caching

      # Clean up after tests
      OasRails.config.enable_caching = false
      OasRails.clear_cache!
    end

    test 'should return the front' do
      get '/docs'
      assert_response :ok
    end

    test 'should return the oas' do
      get '/docs', as: :json
      assert_response :ok
    end

    test "should get index" do
      get "/docs"
      assert_response :success
    end

    test "should get index json" do
      get "/docs", as: :json
      assert_response :success
    end

    test "should get cache status without caching enabled" do
      get "/docs/cache/status", as: :json
      assert_response :success

      json_response = JSON.parse(response.body)
      assert_equal false, json_response["caching_enabled"]
      assert_equal false, json_response["is_cached"]
      # cache_key should not be included when caching is disabled
      refute_includes json_response, "cache_key"
    end

    test "should get cache status with caching enabled" do
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }
      OasRails.config.cache_ttl = 30.minutes

      get "/docs/cache/status", as: :json
      assert_response :success

      json_response = JSON.parse(response.body)
      assert_equal true, json_response["caching_enabled"]
      # The cache might not be populated yet since we haven't made a request to build the spec
      assert_includes [true, false], json_response["is_cached"]
      assert_equal 1800, json_response["cache_ttl"]

      # Now make a request to actually build and cache the spec
      get "/docs", as: :json
      assert_response :success

      # Check cache status again - now it should be cached
      get "/docs/cache/status", as: :json
      assert_response :success

      json_response = JSON.parse(response.body)
      assert_equal true, json_response["is_cached"], "Spec should be cached after building"
    end

    test "should clear cache via DELETE" do
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }

      # Build spec to populate cache
      OasRails.build
      assert OasRails.cached?

      delete "/docs/cache", as: :json
      assert_response :success

      json_response = JSON.parse(response.body)
      assert_equal "Cache cleared successfully", json_response["message"]

      # Verify cache was cleared
      refute OasRails.cached?
    end

    test "should clear cache via POST" do
      OasRails.config.enable_caching = true
      OasRails.config.cache_key_generator = ->(request, config) { "test_cache_key" }

      # Build spec to populate cache
      OasRails.build
      assert OasRails.cached?

      post "/docs/cache/clear", as: :json
      assert_response :success

      json_response = JSON.parse(response.body)
      assert_equal "Cache cleared successfully", json_response["message"]

      # Verify cache was cleared
      refute OasRails.cached?
    end
  end
end
