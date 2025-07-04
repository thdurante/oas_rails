# Configuration

To configure OasRails, **you MUST create an initializer file** including all your settings. The first step is to create your initializer file, which you can easily do with:

```bash
rails generate oas_rails:config
```

Then fill it with your data. Below are the available configuration options:

### Basic Information about the API

- `config.info.title`: The title of your API documentation.

- `config.info.summary`: A brief summary of your API.

- `config.info.description`: A detailed description of your API. This can include markdown formatting and will be displayed prominently in your documentation.

- `config.info.favicon`: The favicon for your API documentation. This can be:
  - An asset pipeline asset (e.g., `'favicon.ico'`, `'icons/custom-favicon.png'`)
  - A static file in the public directory (e.g., `'/favicon.ico'`, `'/assets/favicon.png'`)
  - A full URL (e.g., `'https://example.com/favicon.ico'`)
  
  The favicon will be automatically resolved at runtime, supporting assets with digests when using the asset pipeline.

- `config.info.contact.name`: The name of the contact person or organization.

- `config.info.contact.email`: The contact email address.

- `config.info.contact.url`: The URL for more information or support.

### Servers Information

- `config.servers`: Defines the server URLs for your API. This can be configured in three ways:

  **Array Configuration (Static)**: An array of server objects, each containing `url` and `description` keys:
  
  ```ruby
  config.servers = [
    { url: 'https://api.production.com', description: 'Production Server' },
    { url: 'https://api.staging.com', description: 'Staging Server' },
    { url: 'http://localhost:3000', description: 'Development Server' }
  ]
  ```

  **Lambda/Proc Configuration (Dynamic)**: A lambda or proc that returns an array of server objects, allowing for runtime server definition based on environment variables, Rails environment, or other dynamic conditions:
  
  ```ruby
  config.servers = -> {
    if Rails.env.production?
      [{ url: 'https://api.production.com', description: 'Production Server' }]
    elsif Rails.env.staging?
      [{ url: 'https://api.staging.com', description: 'Staging Server' }]
    else
      [{ url: 'http://localhost:3000', description: 'Development Server' }]
    end
  }
  ```
  
  ```ruby
  # Using environment variables for dynamic configuration
  config.servers = -> {
    base_url = ENV['API_BASE_URL'] || 'http://localhost:3000'
    [{ url: base_url, description: "#{Rails.env.capitalize} Server" }]
  }
  ```

  **Request-Aware Lambda/Proc Configuration**: A lambda or proc that accepts a request parameter, enabling server configuration based on the current request context (host, subdomain, headers, etc.):
  
  ```ruby
  # Multi-tenant configuration based on subdomain
  config.servers = ->(request) {
    if request && request.subdomain.present?
      [{ url: "https://#{request.subdomain}.api.yourdomain.com", description: "#{request.subdomain.capitalize} API" }]
    else
      [{ url: 'https://api.yourdomain.com', description: 'Main API' }]
    end
  }
  ```
  
  ```ruby
  # Configuration based on request host
  config.servers = ->(request) {
    if request && request.host.include?('staging')
      [{ url: "https://#{request.host}", description: 'Staging API' }]
    elsif request && request.host.include?('production')
      [{ url: "https://#{request.host}", description: 'Production API' }]
    else
      [{ url: 'http://localhost:3000', description: 'Development API' }]
    end
  }
  ```
  
  ```ruby
  # Multi-region configuration based on request headers
  config.servers = ->(request) {
    region = request&.headers&.[]('X-Region') || 'us-east-1'
    [{ url: "https://api-#{region}.yourdomain.com", description: "API - #{region.upcase}" }]
  }
  ```

  **Note**: The request parameter is only available when the OpenAPI specification is generated in response to an HTTP request (e.g., when accessing the JSON endpoint). For static generation or when no request context is available, the request parameter will be `nil`.

  For more details about server objects, refer to the [OpenAPI Specification](https://spec.openapis.org/oas/latest.html#server-object).

#### Server Variables

OasRails supports **server variables** following the OpenAPI 3.0+ specification, which allows users to customize server URLs directly in the documentation interface. This is particularly useful for multi-tenant applications or when users need to specify their own server endpoints.

**Default Server Variables**: OasRails automatically includes a dynamic server with variables by default:

```ruby
# This server is included automatically in default_servers
{
  url: "https://{defaultHost}",
  description: "Dynamic Server (enter your host)",
  variables: {
    defaultHost: {
      default: "api.deployhq.com",
      description: "Your server host (e.g., sg.deployhq.com for customer-specific endpoints)"
    }
  }
}
```

**Custom Server Variables Configuration**: You can define servers with variables in any of the configuration methods:

```ruby
# Array configuration with server variables
config.servers = [
  {
    url: "https://{environment}.api.{domain}",
    description: "Environment and domain configurable API",
    variables: {
      environment: {
        default: "staging",
        enum: ["staging", "production"],
        description: "API environment"
      },
      domain: {
        default: "example.com",
        description: "Your domain name"
      }
    }
  }
]
```

```ruby
# Lambda configuration with server variables
config.servers = -> {
  [
    {
      url: "https://{customerHost}",
      description: "Customer-specific API endpoint",
      variables: {
        customerHost: {
          default: "api.yourcompany.com",
          description: "Enter your customer-specific host (e.g., customer1.api.yourcompany.com)"
        }
      }
    }
  ]
}
```

```ruby
# Request-aware configuration with server variables
config.servers = ->(request) {
  base_host = request&.host || "localhost:3000"
  [
    {
      url: "https://{subdomain}.#{base_host}",
      description: "Multi-tenant API",
      variables: {
        subdomain: {
          default: "api",
          description: "Your tenant subdomain"
        }
      }
    }
  ]
}
```

**Server Variable Properties**:
- `default`: (Required) The default value for the variable
- `enum`: (Optional) An array of valid values for the variable
- `description`: (Optional) A description shown to users in the documentation interface

This feature is especially useful for:
- **Multi-tenant applications** where customers access different subdomains
- **Environment selection** where users need to choose between staging/production
- **Regional deployments** where users need to specify their region
- **Customer-specific endpoints** where each customer has their own API host

### Tag Information

- `config.tags`: An array of tag objects, each containing `name` and `description` keys. For more details, refer to the [OpenAPI Specification](https://spec.openapis.org/oas/latest.html#tag-object).

### Optional Settings

- `config.include_mode`: Determines the mode for including operations. The default value is `all`, which means it will include all route operations under the `api_path`, whether documented or not. Other possible values:
  - `:with_tags`: Includes in your OAS only the operations with at least one tag. Example:

    Not included:

    ```ruby
    def update
    end
    ```

    Included:

    ```ruby
    # @summary Return all Books
    def index
    end
    ```

  - `:explicit`: Includes in your OAS only the operations tagged with `@oas_include`. Example:

    Not included:

    ```ruby
    def update
    end
    ```

    Included:

    ```ruby
    # @oas_include
    def index
    end
    ```

- `config.api_path`: Sets the API path if your API is under a different namespace than the root. This is important to configure if you have the `include_mode` set to `all` because it will include all routes of your app in the final OAS. For example, if your app has additional routes and your API is under the namespace `/api`, set this configuration as follows:

  ```ruby
  config.api_path = "/api"
  ```

- `config.ignored_actions`: Defines an array of controller or controller#action pairs. You do not need to prepend the `api_path`. This is useful when you want to include all routes except a few specific actions or when an external engine (e.g., Devise) adds routes to your API.

- `config.default_tags_from`: Determines the source of default tags for operations. Can be set to `:namespace` or `:controller`. The first option means that if your endpoint is in the route `/users/:id`, it will be tagged with `Users`. If set to `controller`, the tag will be `UsersController`.

- `config.autodiscover_request_body`: Automatically detects request bodies for create/update methods. Default is `true`.
- `config.autodiscover_responses`: Automatically detects responses from controller renders. Default is `true`.
- `config.http_verbs`: Defaults to `[:get, :post, :put, :patch, :delete]`
- `config.use_model_names`: Use model names when possible, defaults to `false`

### Authentication Settings

- `config.authenticate_all_routes_by_default`: Determines whether to authenticate all routes by default. Default is `true`.

- `config.security_schema`: The default security schema used for authentication. Choose from the following predefined options:
  - `:api_key_cookie`: API key passed via HTTP cookie.
  - `:api_key_header`: API key passed via HTTP header.
  - `:api_key_query`: API key passed via URL query parameter.
  - `:basic`: HTTP Basic Authentication.
  - `:bearer`: Bearer token (generic).
  - `:bearer_jwt`: Bearer token formatted as a JWT (JSON Web Token).
  - `:mutual_tls`: Mutual TLS authentication (mTLS).

- `config.security_schemas`: Custom security schemas. Follow the [OpenAPI Specification](https://spec.openapis.org/oas/latest.html#security-scheme-object) for defining these schemas.

### Default Errors

- **`config.set_default_responses`**: Determines whether to add default error responses to endpoints. Default is `true`.

- **`config.possible_default_responses`**: An array of possible default error responses. Some responses are added conditionally based on the endpoint (e.g., `:not_found` only applies to `show`, `update`, or `delete` actions).  
  **Default**: `[:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_entity]`  
  **Allowed Values**: Symbols representing HTTP status codes from the list:  
  `[:not_found, :unauthorized, :forbidden, :internal_server_error, :unprocessable_entity]`

- **`config.response_body_of_default`**: The response body template for default error responses. Must be a string representing a hash, similar to those used in request body tags.  
  **Default**: `"Hash{ message: String }"`

- **`config.response_body_of_{code symbol}`**: Customizes the response body for specific error responses. Must be a string representing a hash, similar to `response_body_of_default`. If not specified, it defaults to the value of `response_body_of_default`.  

  **Examples**:

  ```ruby
  # Customize the response body for "unprocessable_entity" errors
  config.response_body_of_unprocessable_entity = "Hash{ errors: Array<String> }"

  # Customize the response body for "forbidden" errors
  config.response_body_of_forbidden = "Hash{ code: Integer, message: String }"
  ```

### Project License

- `config.info.license.name`: The title name of your project's license. Default: GPL 3.0

- `config.info.license.url`: The URL to the full license text. Default: <https://www.gnu.org/licenses/gpl-3.0.html#license-text>
