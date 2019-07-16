require "rails_helper"

RSpec.feature "Teacher verifies identity using GOV.UK Verify" do
  before do
    stub_vsp_generate_request

    @claim = start_tslr_claim
    choose_qts_year
    choose_school schools(:penistone_grammar_school)
    choose_still_teaching
    choose_subjects_taught
  end

  context "successful verification" do
    before do
      stub_vsp_translate_response_request
    end

    scenario "with JavaScript enabled", js: true do
      expect(page).to have_text("You are eligible to claim back student loan repayments")

      click_on "Continue to GOV.UK Verify"
      # Submit the form generated by our FakeSso
      click_on "Perform identity check"

      expect(page).to have_text("We have verified your identity")
      click_on "Continue"

      expect(page).to have_text(I18n.t("tslr.questions.teacher_reference_number"))

      @claim.reload
      expect(@claim.full_name).to eql("Isambard Kingdom Brunel")
      expect(@claim.address_line_1).to eq("Verified Street")
      expect(@claim.address_line_2).to eq("Verified Town")
      expect(@claim.address_line_3).to eq("Verified County")
      expect(@claim.postcode).to eq("M12 345")
      expect(@claim.date_of_birth).to eq(Date.new(1806, 4, 9))
    end

    scenario "successful verification with JavaScript disabled" do
      click_on "Continue to GOV.UK Verify"
      # non-JS means we need to manually submit the /verify/authentications/new form
      click_on "Continue"
      # Submit the form generated by our FakeSso
      click_on "Perform identity check"

      expect(page).to have_text("We have verified your identity")
      click_on "Continue"

      expect(page).to have_text(I18n.t("tslr.questions.teacher_reference_number"))

      @claim.reload
      expect(@claim.full_name).to eql("Isambard Kingdom Brunel")
    end
  end

  context "cancelled response" do
    before do
      stub_vsp_translate_response_request("no-authentication")
    end

    scenario "shows the no_authentication error", js: true do
      click_on "Continue to GOV.UK Verify"
      # Submit the form generated by our FakeSso
      click_on "Perform identity check"

      expect(page).to have_text("you did not complete the process")
    end
  end

  context "failed response" do
    before do
      stub_vsp_translate_response_request("authentication-failed")
    end

    scenario "shows the failed error", js: true do
      click_on "Continue to GOV.UK Verify"
      # Submit the form generated by our FakeSso
      click_on "Perform identity check"

      expect(page).to have_text("the company you chose does not have enough information about you")
    end
  end
end
