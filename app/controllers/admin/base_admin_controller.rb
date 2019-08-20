module Admin
  class BaseAdminController < ApplicationController
    before_action :ensure_authenticated_user

    private

    def ensure_authenticated_user
      redirect_to admin_sign_in_path unless admin_signed_in?
    end

    def admin_session
      @admin_session ||= AdminSession.new(session[:user_id], session[:organisation_id], session[:role_codes])
    end

    def service_operator_signed_in?
      admin_session.is_service_operator?
    end
  end
end
