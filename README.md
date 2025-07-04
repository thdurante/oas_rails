![Gem Version](https://img.shields.io/gem/v/oas_rails?color=E9573F)
![GitHub License](https://img.shields.io/github/license/a-chacon/oas_rails?color=blue)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/a-chacon/oas_rails/.github%2Fworkflows%2Frubyonrails.yml)
![Gem Total Downloads](https://img.shields.io/gem/dt/oas_rails)
![Static Badge](https://img.shields.io/badge/Rails-%3E%3D7.0.0-%23E9573F)
![Static Badge](https://img.shields.io/badge/Ruby-%3E%3D3.1.0-%23E9573F)

# 📃Open API Specification For Rails

OasRails is a Rails engine for generating **automatic interactive documentation for your Rails APIs**. It generates an **OAS 3.1** document and displays it using **[RapiDoc](https://rapidocweb.com)**.

### 🚀 Demo App

Explore the interactive documentation live:

🔗 **[Open Demo App](https://paso.fly.dev/api/docs)**  
👤 **Username**: `oasrails`  
🔑 **Password**: `oasrails`

🎬 A Demo Installation/Usage Video:
<https://vimeo.com/1013687332>
🎬

![Screenshot](https://a-chacon.com/assets/images/oas_rails_ui.png)

## ✨ Key Features

- **Dynamic Server Variables**: Configure server URLs with variables that users can customize directly in the documentation interface - perfect for multi-tenant applications where customers need to specify their subdomain or custom endpoints
- **Automatic Documentation**: Generate interactive API documentation without additional DSLs or complex configurations
- **Rails-Native**: Built specifically for Rails APIs using standard REST conventions
- **Live Documentation**: Documentation updates automatically as your code changes

## Related Projects

- **[ApiPie](https://github.com/Apipie/apipie-rails)**: Doesn't support OAS 3.1, requires learning a DSL, lacks a nice UI
- **[swagger_yard-rails](https://github.com/livingsocial/swagger_yard-rails)**: Seems abandoned, but serves as inspiration
- **[Rswag](https://github.com/rswag/rswag)**: Not automatic, depends on RSpec; Many developers now use Minitest as it's the default test framework
- **[grape-swagger](https://github.com/ruby-grape/grape-swagger)**: Requires Grape
- **[rspec_api_documentation](https://github.com/zipmark/rspec_api_documentation)**: Requires RSpec and a command to generate the docs

## What Sets OasRails Apart?

- **Dynamic**: No command required to generate docs
- **Simple**: Complement default documentation with a few comments; no need to learn a complex DSL
- **Pure Ruby on Rails APIs**: No additional frameworks needed (e.g., Grape, RSpec)
- **User-Friendly**: Server variables allow customers to test endpoints on their own domains/subdomains

## 📽️ Motivation

After experiencing the interactive documentation in Python's fast-api framework, I sought similar functionality in Ruby on Rails. Unable to find a suitable solution, I [asked on Stack Overflow](https://stackoverflow.com/questions/71947018/is-there-a-way-to-generate-an-interactive-documentation-for-rails-apis) years ago. Now, with some free time while freelancing as an API developer, I decided to build my own tool.

**Note: This is not yet a production-ready solution. The code may be rough and behave unexpectedly, but I am actively working on improving it. If you like the idea, please consider contributing to its development.**

The goal is to minimize the effort required to create comprehensive documentation. By following REST principles in Rails, we believe this is achievable. You can enhance the documentation using [Yard](https://yardoc.org/) tags.

## Documentation

For see how to install, configure and use OasRails please refere to the [OasRailsBook](http://a-chacon.com/oas_rails)

## Configuration

### Caching

OasRails supports caching of the OpenAPI specification to improve performance, especially useful for applications with many routes or complex specifications.

```ruby
# config/initializers/oas_rails.rb
OasRails.configure do |config|
  # Enable caching (default: false)
  config.enable_caching = true
  
  # Cache Time-To-Live - how long the cache is valid (default: 1.hour)
  config.cache_ttl = 30.minutes
  
  # Cache key generator - REQUIRED when caching is enabled
  # Provide a proc that receives (request, config) and returns a cache key
  config.cache_key_generator = ->(request, config) {
    "my_app_oas_#{request&.host || 'default'}_#{Rails.env}_#{config.include_mode}"
  }
  
  # Enable cache debugging (default: false)
  # Logs cache operations to Rails logger for troubleshooting
  config.cache_debug = true
end
```

**Important**: When `enable_caching` is `true`, you **must** provide a `cache_key_generator`. The gem will raise an `ArgumentError` if the cache key generator is missing.

#### Cache Management

When caching is enabled, you can manage the cache through API endpoints or programmatically:

**API Endpoints:**
- `GET /your-oas-path/cache/status.json` - Check cache status and configuration
- `DELETE /your-oas-path/cache.json` - Clear cache
- `POST /your-oas-path/cache/clear.json` - Clear cache

**Programmatic:**
```ruby
# Clear cache programmatically
OasRails.clear_cache!

# Check if specification is cached
OasRails.cached?
```

#### Cache Debugging

Enable `cache_debug` to see cache operations in your Rails logs:

```
[OasRails Cache] Cache key generated: my_app_oas_default_development_all
[OasRails Cache] Cache MISS for key: my_app_oas_default_development_all
[OasRails Cache] Storing in cache with key: my_app_oas_default_development_all, TTL: 1800
[OasRails Cache] Cache write SUCCESS for key: my_app_oas_default_development_all
[OasRails Cache] Cache cleared for key: my_app_oas_default_development_all - SUCCESS
```

The cache is automatically invalidated in development environment (unless caching is explicitly enabled) but persists in production until it expires or is manually cleared.

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**. If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement". Don't forget to give the project a star⭐! Thanks again!

If you plan a big feature, first open an issue to discuss it before any development.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

The gem is available as open source under the terms of the [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html#license-text).

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=a-chacon/oas_rails&type=Date)](https://www.star-history.com/#a-chacon/oas_rails&Date)
