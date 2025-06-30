module OasRails
  class OasRailsController < ApplicationController
    # Include URL help if the layout is a user-customized layout.
    include Rails.application.routes.url_helpers

    skip_before_action :verify_authenticity_token, only: [:cache_status, :clear_cache]

    def index
      respond_to do |format|
        format.html { render "index", layout: OasRails.config.layout }
        format.json do
          render json: OasRails.build(request: request).to_json, status: :ok
        end
      end
    end

    # Show cache status information
    def cache_status
      respond_to do |format|
        format.json do
          status_data = {
            caching_enabled: OasRails.config.enable_caching,
            cache_ttl: OasRails.config.cache_ttl,
            cache_debug: OasRails.config.cache_debug,
            custom_key_generator: OasRails.config.cache_key_generator.present?,
            is_cached: OasRails.cached?(request: request)
          }

          # Only include cache_key if caching is enabled and key generator is available
          status_data[:cache_key] = OasRails.send(:generate_cache_key, request) if OasRails.config.enable_caching && OasRails.config.cache_key_generator.respond_to?(:call)

          render json: status_data, status: :ok
        end
      end
    end

    # Clear the OpenAPI specification cache
    def clear_cache
      OasRails.clear_cache!

      respond_to do |format|
        format.json do
          render json: { message: "Cache cleared successfully" }, status: :ok
        end
      end
    end
  end
end
