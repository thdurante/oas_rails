require "test_helper"
require "ostruct"

module OasRails
  class ConfigurationTest < ActiveSupport::TestCase
    def setup
      @config = Configuration.new
    end

    test "initializes with default values" do
      assert_equal "3.1.0", @config.instance_variable_get(:@swagger_version)
      assert_equal "/", @config.api_path
      assert_equal [], @config.ignored_actions
      assert_equal true, @config.autodiscover_request_body
      assert_equal true, @config.autodiscover_responses
      assert_equal true, @config.authenticate_all_routes_by_default
      assert_equal [:get, :post, :put, :patch, :delete], @config.http_verbs
      assert_equal "Hash{ status: !Integer, error: String }", @config.response_body_of_default
      assert_equal :rails, @config.rapidoc_theme
      assert_equal :all, @config.include_mode
      assert_equal false, @config.layout
      assert_equal :namespace, @config.default_tags_from
      assert_equal nil, @config.security_schema
      assert_equal({}, @config.security_schemas)
      assert_equal true, @config.set_default_responses
      assert_equal [:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_entity], @config.possible_default_responses
      assert_equal false, @config.use_model_names
      assert_equal false, @config.enable_caching
      assert_equal 1.hour, @config.cache_ttl
      assert_equal :rails_cache, @config.cache_store
      assert_nil @config.cache_key_generator
      assert_equal false, @config.cache_debug
    end

    test "sets and gets servers with array" do
      servers = [{ url: "https://example.com", description: "Example Server" }]
      @config.servers = servers
      assert_equal 1, @config.servers.size
      assert_equal "https://example.com", @config.servers.first.url
      assert_equal "Example Server", @config.servers.first.description
    end

    test "sets and gets servers with proc/lambda" do
      servers_proc = -> { [{ url: "https://dynamic.com", description: "Dynamic Server" }] }
      @config.servers = servers_proc

      result = @config.servers
      assert_equal 1, result.size
      assert_equal "https://dynamic.com", result.first.url
      assert_equal "Dynamic Server", result.first.description
    end

    test "servers proc can access runtime variables" do
      Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
        servers_proc = lambda {
          if Rails.env.production?
            [{ url: "https://api.production.com", description: "Production Server" }]
          else
            [{ url: "http://localhost:3000", description: "Development Server" }]
          end
        }
        @config.servers = servers_proc

        result = @config.servers
        assert_equal 1, result.size
        assert_equal "https://api.production.com", result.first.url
        assert_equal "Production Server", result.first.description
      end
    end

    test "servers proc with development environment" do
      Rails.stub(:env, ActiveSupport::StringInquirer.new("development")) do
        servers_proc = lambda {
          if Rails.env.production?
            [{ url: "https://api.production.com", description: "Production Server" }]
          else
            [{ url: "http://localhost:3000", description: "Development Server" }]
          end
        }
        @config.servers = servers_proc

        result = @config.servers
        assert_equal 1, result.size
        assert_equal "http://localhost:3000", result.first.url
        assert_equal "Development Server", result.first.description
      end
    end

    test "servers proc with request parameter" do
      # Create a mock request object
      request = OpenStruct.new(
        host: "api.example.com",
        subdomain: "staging",
        headers: { "X-Environment" => "staging" }
      )

      servers_proc = lambda { |req|
        if req && req.host == "api.example.com"
          [{ url: "https://#{req.host}", description: "Dynamic Host Server" }]
        else
          [{ url: "http://localhost:3000", description: "Default Server" }]
        end
      }
      @config.servers = servers_proc

      result = @config.servers(request)
      assert_equal 1, result.size
      assert_equal "https://api.example.com", result.first.url
      assert_equal "Dynamic Host Server", result.first.description
    end

    test "servers proc with request subdomain routing" do
      request = OpenStruct.new(
        subdomain: "tenant1",
        host: "myapp.com"
      )

      servers_proc = lambda { |req|
        if req && req.subdomain.present?
          [{ url: "https://#{req.subdomain}.api.#{req.host}", description: "Tenant API" }]
        else
          [{ url: "https://api.#{req&.host || 'localhost:3000'}", description: "Main API" }]
        end
      }
      @config.servers = servers_proc

      result = @config.servers(request)
      assert_equal 1, result.size
      assert_equal "https://tenant1.api.myapp.com", result.first.url
      assert_equal "Tenant API", result.first.description
    end

    test "servers proc without request parameter (backward compatibility)" do
      servers_proc = lambda {
        [{ url: "https://no-request.com", description: "No Request Server" }]
      }
      @config.servers = servers_proc

      # Should work with both nil request and no request parameter
      result1 = @config.servers(nil)
      assert_equal "https://no-request.com", result1.first.url

      result2 = @config.servers
      assert_equal "https://no-request.com", result2.first.url
    end

    test "servers proc can return multiple servers" do
      servers_proc = lambda {
        [
          { url: "https://api.example.com", description: "Production API" },
          { url: "https://staging.example.com", description: "Staging API" },
          { url: "http://localhost:3000", description: "Local Development" }
        ]
      }
      @config.servers = servers_proc

      result = @config.servers
      assert_equal 3, result.size
      assert_equal "https://api.example.com", result[0].url
      assert_equal "https://staging.example.com", result[1].url
      assert_equal "http://localhost:3000", result[2].url
    end

    test "servers proc can return multiple servers based on request" do
      request = OpenStruct.new(
        headers: { "X-Multi-Region" => "true" }
      )

      servers_proc = lambda { |req|
        if req && req.headers["X-Multi-Region"] == "true"
          [
            { url: "https://us-east.api.com", description: "US East API" },
            { url: "https://us-west.api.com", description: "US West API" },
            { url: "https://eu.api.com", description: "EU API" }
          ]
        else
          [{ url: "https://single.api.com", description: "Single API" }]
        end
      }
      @config.servers = servers_proc

      result = @config.servers(request)
      assert_equal 3, result.size
      assert_equal "https://us-east.api.com", result[0].url
      assert_equal "https://us-west.api.com", result[1].url
      assert_equal "https://eu.api.com", result[2].url
    end

    test "servers proc that returns invalid data raises error" do
      servers_proc = -> { "invalid" }
      @config.servers = servers_proc

      assert_raises(ArgumentError, "servers proc must return an Array") do
        @config.servers
      end
    end

    test "servers with invalid type raises error" do
      assert_raises(ArgumentError, "servers must be an Array or a Proc") do
        @config.servers = "invalid"
      end

      assert_raises(ArgumentError, "servers must be an Array or a Proc") do
        @config.servers = { url: "test" }
      end
    end

    test "servers defaults to default_servers when no static or proc set" do
      # Reset both to nil to test fallback
      @config.instance_variable_set(:@servers_static, nil)
      @config.instance_variable_set(:@servers_proc, nil)

      result = @config.servers
      assert_equal 2, result.size
      assert_equal "http://localhost:3000", result.first.url
      assert_equal "Rails Default Development Server", result.first.description
      # Test the new dynamic server with variables
      assert_equal "https://{defaultHost}", result.last.url
      assert_equal "Dynamic Server (enter your host)", result.last.description
      assert_not_nil result.last.variables
      assert_equal "api.domain.com", result.last.variables[:defaultHost].default
    end

    test "switching between array and proc configurations" do
      # Start with array
      @config.servers = [{ url: "https://array.com", description: "Array Server" }]
      result = @config.servers
      assert_equal "https://array.com", result.first.url

      # Switch to proc
      @config.servers = -> { [{ url: "https://proc.com", description: "Proc Server" }] }
      result = @config.servers
      assert_equal "https://proc.com", result.first.url

      # Switch back to array
      @config.servers = [{ url: "https://array2.com", description: "Array Server 2" }]
      result = @config.servers
      assert_equal "https://array2.com", result.first.url
    end

    test "sets and gets tags" do
      tags = [{ name: "Users", description: "Operations about users" }]
      @config.tags = tags
      assert_equal 1, @config.tags.size
      assert_equal "Users", @config.tags.first.name
      assert_equal "Operations about users", @config.tags.first.description
    end

    test "validates include_mode" do
      assert_nothing_raised { @config.include_mode = :with_tags }
      assert_nothing_raised { @config.include_mode = :explicit }
      assert_raises(ArgumentError) { @config.include_mode = :invalid_mode }
    end

    test "validates response_body_of_default" do
      assert_nothing_raised { @config.response_body_of_default = "String" }

      assert_raises(ArgumentError) { @config.response_body_of_default = 123 }
    end

    test "sets security_schema" do
      @config.security_schema = :api_key_header
      assert_equal 1, @config.security_schemas.size
      assert_equal "apiKey", @config.security_schemas[:api_key_header][:type]
    end

    test "ignores invalid security_schema" do
      @config.security_schema = :invalid_schema
      assert_empty @config.security_schemas
    end

    test "dynamic response_body_of_<e> setters and getters" do
      @config.response_body_of_not_found = "String"
      assert_equal "String", @config.response_body_of_not_found

      assert_equal @config.response_body_of_default, @config.response_body_of_unauthorized

      assert_raises(ArgumentError) { @config.response_body_of_forbidden = 123 }
    end

    test "all dynamic response_body_of_<e> methods are defined" do
      @config.possible_default_responses.each do |response|
        assert_respond_to @config, "response_body_of_#{response}="
        assert_respond_to @config, "response_body_of_#{response}"
      end
    end

    test "servers with variables work correctly" do
      servers = [
        {
          url: "https://{environment}.api.example.com",
          description: "Environment-specific API",
          variables: {
            environment: {
              default: "staging",
              enum: %w[staging production],
              description: "API environment"
            }
          }
        }
      ]
      @config.servers = servers

      result = @config.servers
      assert_equal 1, result.size
      server = result.first
      assert_equal "https://{environment}.api.example.com", server.url
      assert_equal "Environment-specific API", server.description
      assert_not_nil server.variables
      assert_not_nil server.variables[:environment]
      assert_equal "staging", server.variables[:environment].default
      assert_equal %w[staging production], server.variables[:environment].enum
      assert_equal "API environment", server.variables[:environment].description
    end

    test "info initialize accepts favicon parameter" do
      info = OasRails::Spec::Info.new(favicon: 'custom-favicon.ico')
      assert_equal 'custom-favicon.ico', info.favicon
    end

    test "info favicon defaults to nil" do
      info = OasRails::Spec::Info.new
      assert_nil info.favicon
    end

    test "info favicon can be set after initialization" do
      info = OasRails::Spec::Info.new
      info.favicon = '/path/to/favicon.png'
      assert_equal '/path/to/favicon.png', info.favicon
    end

    test "enable_caching can be set" do
      @config.enable_caching = true
      assert_equal true, @config.enable_caching
    end

    test "cache_ttl can be set" do
      @config.cache_ttl = 30.minutes
      assert_equal 30.minutes, @config.cache_ttl
    end

    test "cache_store can be set" do
      @config.cache_store = :memory
      assert_equal :memory, @config.cache_store
    end

    test "security_schema setter" do
      @config.security_schema = :bearer

      assert_equal({ bearer: { type: "http", scheme: "bearer", description: "A bearer token that will be supplied within an `Authorization` header as `bearer <token>`." } }, @config.security_schemas)
    end

    test "servers setting via array" do
      servers = [
        { url: "http://test.com", description: "test server" }
      ]
      @config.servers = servers

      result = @config.servers

      assert_equal "http://test.com", result.first.url
      assert_equal "test server", result.first.description
    end

    test "servers setting via proc" do
      @config.servers = -> { [{ url: "http://dynamic.com", description: "dynamic server" }] }

      result = @config.servers

      assert_equal "http://dynamic.com", result.first.url
      assert_equal "dynamic server", result.first.description
    end

    test "response_body_default_setter" do
      valid_type = "Hash{ message: String }"
      @config.response_body_of_default = valid_type
      assert_equal valid_type, @config.response_body_of_default

      assert_raises(ArgumentError) do
        @config.response_body_of_default = 123
      end
    end

    test "response_body_of_not_found" do
      valid_type = "Hash{ error: String }"
      @config.response_body_of_not_found = valid_type
      assert_equal valid_type, @config.response_body_of_not_found
    end

    test "cache_store can be set to memory" do
      @config.cache_store = :memory
      assert_equal :memory, @config.cache_store
    end

    test "cache_key_generator can be set" do
      generator = ->(request, config) { "test_#{request&.host}" }
      @config.cache_key_generator = generator
      assert_equal generator, @config.cache_key_generator
    end

    test "cache_debug can be set" do
      @config.cache_debug = true
      assert_equal true, @config.cache_debug
    end
  end
end
