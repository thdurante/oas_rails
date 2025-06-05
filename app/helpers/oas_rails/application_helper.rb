module OasRails
  module ApplicationHelper
    def favicon_link_tag_for_oas_rails
      return unless OasRails.config.info.favicon.present?

      favicon_path = resolve_favicon_path(OasRails.config.info.favicon)
      favicon_link_tag(favicon_path) if favicon_path
    end

    private

    def resolve_favicon_path(favicon)
      return nil if favicon.blank?

      # If it's already a full URL (starts with http/https), return as-is
      return favicon if favicon.match?(%r{\Ahttps?://})

      # If it's a path starting with '/', treat as static asset in public/
      return favicon if favicon.start_with?('/')

      # Otherwise, try to resolve through asset pipeline using image_path
      begin
        # Use image_path which should work in both engine and application contexts
        if respond_to?(:image_path)
          image_path(favicon)
        else
          # Fallback: just return the original path
          Rails.logger.warn("OasRails: image_path helper not available, using favicon path as-is: '#{favicon}'")
          favicon
        end
      rescue StandardError => e
        Rails.logger.warn("OasRails: Could not resolve favicon path '#{favicon}': #{e.message}")
        favicon
      end
    end
  end
end
