# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  protect_from_forgery
  require 'authlogic'

  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Scrub sensitive parameters from your log
  filter_parameter_logging :password, :password_confirmation, :fb_sig_friends
  helper :all
  helper_method :current_user_session, :current_user, :logged_in?, :admin_logged_in?

  before_filter :flash

  private

    def not_allowed
      flash[:warning] = "You're not allowed to perform that action"
      redirect_to root_url
    end

    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end

    def logged_in?
      !!current_user
    end
    def admin_logged_in?
      logged_in? && current_user.admin?
    end

    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      else
        require_complete_profile unless completing_profile?
      end
    end

    def require_complete_profile
      unless current_user.profile_complete?
        store_location
        flash[:notice] = "We need you to complete your profile before being able to use the site"
        redirect_to edit_account_url
        return false
      end
    end

    def completing_profile?
      (params[:controller] == "users" && %w(edit update).include?(params[:action])) ||
        (params[:controller] == "user_sessions" && params[:action] == "destroy")
    end
    
    def require_admin
      not_allowed unless admin_logged_in?
    end

    def require_no_user
      if current_user
        store_location
        # When we upgraded Rails and Ruby Gems from 2.3.5 and 1.3.7 respectively,
        # flash messages disappeared for logged in users. We resolve this by
        # keeping the flash for the next action. Pretty straight-forward, except
        # that flash.keep doesn't work unless flash is called in a before_filter
        # that is called before this one (even if it's the filter called 
        # immediately before this one). It may be just that @_flash needs to 
        # exist before this filter is invoked.
        flash.keep
        redirect_to account_url
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
end
