OasRails::Engine.routes.draw do
  get '(.:format)', to: 'oas_rails#index'

  with_options defaults: { format: :json } do
    get 'cache/status(.:format)', to: 'oas_rails#cache_status'
    delete 'cache(.:format)', to: 'oas_rails#clear_cache'
    post 'cache/clear(.:format)', to: 'oas_rails#clear_cache'
  end
end
