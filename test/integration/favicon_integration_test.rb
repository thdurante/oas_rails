require 'test_helper'

class FaviconIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    # Reset favicon configuration before each test
    OasRails.config.info.favicon = nil
  end

  def teardown
    # Reset favicon configuration after each test
    OasRails.config.info.favicon = nil
  end

  test "favicon link tag is not rendered when no favicon is configured" do
    get "/docs"
    assert_response :success
    assert_select "link[rel='icon']", count: 0
  end

  test "favicon link tag is rendered with static path" do
    OasRails.config.info.favicon = "/test-favicon.ico"
    get "/docs"
    assert_response :success
    assert_select "link[rel='icon'][href='/test-favicon.ico']"
  end

  test "favicon link tag is rendered with full URL" do
    OasRails.config.info.favicon = "https://example.com/favicon.ico"
    get "/docs"
    assert_response :success
    assert_select "link[rel='icon'][href='https://example.com/favicon.ico']"
  end

  test "favicon link tag is rendered with asset pipeline asset" do
    OasRails.config.info.favicon = "favicon.png"
    get "/docs"
    assert_response :success
    # The exact path will depend on asset pipeline, but should include the asset
    assert_select "link[rel='icon']" do |elements|
      href = elements.first['href']
      # Check that it's an asset pipeline path and includes the favicon name
      assert href.include?('favicon'), "Expected favicon path to include 'favicon', got: #{href}"
      assert href.include?('.png'), "Expected favicon path to include '.png', got: #{href}"
      assert href.start_with?('/assets/'), "Expected favicon path to start with '/assets/', got: #{href}"
    end
  end
end
