require 'test_helper'

class OasRails::ApplicationHelperTest < ActionView::TestCase
  include OasRails::ApplicationHelper

  def test_favicon_link_tag_for_oas_rails_returns_nil_when_no_favicon_configured
    OasRails.config.info.favicon = nil
    assert_nil favicon_link_tag_for_oas_rails
  end

  def test_favicon_link_tag_for_oas_rails_returns_nil_when_favicon_is_blank
    OasRails.config.info.favicon = ''
    assert_nil favicon_link_tag_for_oas_rails
  end

  def test_favicon_link_tag_for_oas_rails_with_static_path
    OasRails.config.info.favicon = '/favicon.ico'
    result = favicon_link_tag_for_oas_rails
    assert_includes result, '/favicon.ico'
    assert_includes result, '<link'
    assert_includes result, 'rel="icon"'
  end

  def test_favicon_link_tag_for_oas_rails_with_full_url
    OasRails.config.info.favicon = 'https://example.com/favicon.ico'
    result = favicon_link_tag_for_oas_rails
    assert_includes result, 'https://example.com/favicon.ico'
    assert_includes result, '<link'
    assert_includes result, 'rel="icon"'
  end

  def test_resolve_favicon_path_with_full_url
    result = resolve_favicon_path('https://example.com/favicon.ico')
    assert_equal 'https://example.com/favicon.ico', result
  end

  def test_resolve_favicon_path_with_http_url
    result = resolve_favicon_path('http://example.com/favicon.ico')
    assert_equal 'http://example.com/favicon.ico', result
  end

  def test_resolve_favicon_path_with_static_path
    result = resolve_favicon_path('/favicon.ico')
    assert_equal '/favicon.ico', result
  end

  def test_resolve_favicon_path_with_blank_input
    assert_nil resolve_favicon_path('')
    assert_nil resolve_favicon_path(nil)
  end

  def test_resolve_favicon_path_with_asset_pipeline
    # Mock the image_path method which is what we now use
    def image_path(asset)
      "/images/#{asset}"
    end

    result = resolve_favicon_path('favicon.ico')
    assert_equal '/images/favicon.ico', result
  end

  def test_favicon_partial_renders_correctly
    OasRails.config.info.favicon = '/test-favicon.ico'

    # Test that the partial can be rendered without errors
    result = render 'oas_rails/shared/favicon'
    assert_includes result, '<link'
    assert_includes result, 'rel="icon"'
    assert_includes result, '/test-favicon.ico'
  end

  private

  # Make resolve_favicon_path public for testing
  def resolve_favicon_path(favicon)
    super
  end
end
