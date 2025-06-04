# Examples

## Controller Example

```ruby
class UsersController < ApplicationController
  before_action :set_user, only: %i[show update destroy]

  # @summary Returns a list of Users.
  #
  # @parameter offset(query) [Integer]  Used for pagination of response data (default: 25 items per response). Specifies the offset of the next block of data to receive.
  # @parameter status(query) [Array<String>]   Filter by status. (e.g. status[]=inactive&status[]=deleted).
  # @parameter X-front(header) [String] Header for identify the front.
  def index
    @users = User.all
  end

  # @summary Get a user by id.
  # @auth [bearer]
  #
  # This method show a User by ID. The id must exist of other way it will be returning a **`404`**.
  #
  # @parameter id(path) [Integer] Used for identify the user.
  # @response Requested User(200) [Hash] {user: {name: String, email: String, created_at: DateTime }}
  # @response User not found by the provided Id(404) [Hash] {success: Boolean, message: String}
  # @response You don't have the right permission for access to this resource(403) [Hash] {success: Boolean, message: String}
  def show
    render json: @user
  end

  # @summary Create a User
  # @no_auth
  #
  # @request_body The user to be created. At least include an `email`. [!User]
  # @request_body_example basic user [Hash] {user: {name: "Luis", email: "luis@gmail.ocom"}}
  def create
    @user = User.new(user_params)

    if @user.save
      render json: @user, status: :created
    else
      render json: { success: false, errors: @user.errors }, status: :unprocessable_entity
    end
  end

  # A `user` can be updated with this method
  # - There is no option
  # - It must work
  # @tags users, update
  # @request_body User to be created [!Hash{user: { name: String, email: !String, age: Integer, available_dates: Array<Date>}}]
  # @request_body_example Update user [Hash] {user: {name: "Luis", email: "luis@gmail.com"}}
  # @request_body_example Complete User [Hash] {user: {name: "Luis", email: "luis@gmail.com", age: 21}}
  def update
    if @user.update(user_params)
      render json: @user
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # @summary Delete a User
  # Delete a user and his associated data.
  def destroy
    @user.destroy!
    redirect_to users_url, notice: 'User was successfully destroyed.', status: :see_other
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:name, :email)
  end
end
```

## Server Variables Configuration Examples

### Multi-Tenant Application (Customer Subdomains)

Perfect for SaaS applications where each customer has their own subdomain:

```ruby
# config/initializers/oas_rails.rb
OasRails.configure do |config|
  config.servers = [
    {
      url: "https://{customerSubdomain}.myapp.com",
      description: "Customer-specific API endpoint",
      variables: {
        customerSubdomain: {
          default: "demo",
          description: "Your customer subdomain (e.g., 'acme' for acme.myapp.com)"
        }
      }
    },
    {
      url: "https://api.myapp.com",
      description: "Main API endpoint"
    }
  ]
end
```

### Environment Selection with Dynamic Hosts

Allow users to switch between staging and production environments:

```ruby
# config/initializers/oas_rails.rb
OasRails.configure do |config|
  config.servers = [
    {
      url: "https://{environment}.api.{domain}",
      description: "Configurable environment and domain",
      variables: {
        environment: {
          default: "staging",
          enum: ["staging", "production"],
          description: "Target environment"
        },
        domain: {
          default: "yourcompany.com",
          description: "Your domain name"
        }
      }
    }
  ]
end
```

### Request-Aware Dynamic Configuration

Dynamically configure servers based on the incoming request:

```ruby
# config/initializers/oas_rails.rb
OasRails.configure do |config|
  config.servers = ->(request) {
    if request && request.subdomain.present?
      # Show tenant-specific server when accessed from subdomain
      [
        {
          url: "https://{subdomain}.#{request.host}",
          description: "Tenant API",
          variables: {
            subdomain: {
              default: request.subdomain,
              description: "Your tenant subdomain"
            }
          }
        }
      ]
    else
      # Show configurable server when accessed from main domain
      [
        {
          url: "https://{customerHost}",
          description: "Customer-specific endpoint",
          variables: {
            customerHost: {
              default: "api.yourcompany.com",
              description: "Enter your customer-specific host"
            }
          }
        }
      ]
    end
  }
end
```

These configurations will automatically display input fields in the RapiDoc interface, allowing your API users to customize the server URL before making test requests.
