module OasRails
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    # Include the application helper to make favicon helper available
    helper ApplicationHelper
  end
end
