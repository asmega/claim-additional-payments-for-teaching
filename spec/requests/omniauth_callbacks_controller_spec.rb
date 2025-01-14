require "rails_helper"

RSpec.describe "OmniauthCallbacksControllers", type: :request do
  describe "#callback" do
    def set_mock_auth(trn)
      OmniAuth.config.mock_auth[:default] = OmniAuth::AuthHash.new(
        "extra" => {
          "raw_info" => {
            "trn" => trn
          }
        }
      )
      Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:default]
    end

    context "when trn is not nil" do
      before do
        set_mock_auth("1234567")

        allow_any_instance_of(OmniauthCallbacksController).to receive(:policy).and_return(Policies::EarlyCareerPayments)
      end

      it "redirects to the claim path with correct parameters" do
        get claim_auth_tid_callback_path

        expect(response).to redirect_to(
          claim_path(
            journey: "additional-payments",
            slug: "sign-in-or-continue",
            claim: {
              logged_in_with_tid: true,
              teacher_id_user_info_attributes: {
                trn: "1234567"
              }
            }
          )
        )
      end
    end

    context "when trn is nil" do
      before do
        set_mock_auth(nil)

        allow_any_instance_of(OmniauthCallbacksController).to receive(:policy).and_return(Policies::StudentLoans)
      end

      it "redirects to the claim path with correct parameters" do
        get claim_auth_tid_callback_path

        expect(response).to redirect_to(
          claim_path(
            journey: "student-loans",
            slug: "sign-in-or-continue",
            claim: {
              logged_in_with_tid: true,
              teacher_id_user_info_attributes: {
                trn: nil
              }
            }
          )
        )
      end
    end

    context "auth failure csrf detected" do
      it "redirects to /auth/failure" do
        OmniAuth.config.mock_auth[:default] = :csrf_detected

        get claim_auth_tid_callback_path

        expect(response).to redirect_to(
          auth_failure_path(message: "csrf_detected", strategy: "tid")
        )
      end
    end
  end
end
