require "test_helper"
require "ostruct"

module OasRails
  module Spec
    class SpecificationTest < ActiveSupport::TestCase
      def setup
        @original_config = OasRails.config.dup
      end

      def teardown
        # Restore original configuration if needed
      end

      test "specification uses static servers configuration" do
        OasRails.config.servers = [
          { url: "https://api.example.com", description: "Production Server" },
          { url: "http://localhost:3000", description: "Development Server" }
        ]

        spec = Specification.new
        assert_equal 2, spec.servers.size
        assert_equal "https://api.example.com", spec.servers.first.url
        assert_equal "Production Server", spec.servers.first.description
      end

      test "specification uses dynamic servers configuration" do
        OasRails.config.servers = lambda {
          [{ url: "https://dynamic.example.com", description: "Dynamic Server" }]
        }

        spec = Specification.new
        assert_equal 1, spec.servers.size
        assert_equal "https://dynamic.example.com", spec.servers.first.url
        assert_equal "Dynamic Server", spec.servers.first.description
      end

      test "specification handles environment-based dynamic servers" do
        Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
          OasRails.config.servers = lambda {
            if Rails.env.production?
              [{ url: "https://api.production.com", description: "Production API" }]
            else
              [{ url: "http://localhost:3000", description: "Development API" }]
            end
          }

          spec = Specification.new
          assert_equal 1, spec.servers.size
          assert_equal "https://api.production.com", spec.servers.first.url
          assert_equal "Production API", spec.servers.first.description
        end
      end

      test "specification re-evaluates lambda on each access" do
        counter = 0
        OasRails.config.servers = lambda {
          counter += 1
          [{ url: "https://api#{counter}.example.com", description: "Server #{counter}" }]
        }

        spec = Specification.new

        # First access
        servers1 = spec.servers
        assert_equal "https://api1.example.com", servers1.first.url

        # Second access should re-evaluate the lambda
        servers2 = spec.servers
        assert_equal "https://api2.example.com", servers2.first.url

        # Third access
        servers3 = spec.servers
        assert_equal "https://api3.example.com", servers3.first.url
      end

      test "specification passes request to servers lambda" do
        request = OpenStruct.new(
          host: "tenant.example.com",
          subdomain: "tenant"
        )

        OasRails.config.servers = lambda { |req|
          if req && req.host.start_with?("tenant")
            [{ url: "https://api.#{req.host}", description: "Tenant API" }]
          else
            [{ url: "http://localhost:3000", description: "Default API" }]
          end
        }

        spec = Specification.new(request: request)
        servers = spec.servers
        assert_equal 1, servers.size
        assert_equal "https://api.tenant.example.com", servers.first.url
        assert_equal "Tenant API", servers.first.description
      end

      test "specification works without request when lambda doesn't require it" do
        OasRails.config.servers = lambda {
          [{ url: "https://static.example.com", description: "Static Server" }]
        }

        spec = Specification.new
        servers = spec.servers
        assert_equal 1, servers.size
        assert_equal "https://static.example.com", servers.first.url
      end

      test "specification with request-aware lambda and nil request" do
        OasRails.config.servers = lambda { |req|
          if req
            [{ url: "https://#{req.host}", description: "Dynamic Server" }]
          else
            [{ url: "http://localhost:3000", description: "Default Server" }]
          end
        }

        spec = Specification.new(request: nil)
        servers = spec.servers
        assert_equal 1, servers.size
        assert_equal "http://localhost:3000", servers.first.url
        assert_equal "Default Server", servers.first.description
      end
    end
  end
end
