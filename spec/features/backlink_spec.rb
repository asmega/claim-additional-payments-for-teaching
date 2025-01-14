require "rails_helper"

RSpec.feature "Backlinking during a claim" do
  scenario "Student Loans journey" do
    create(:journey_configuration, :student_loans)
    school = create(:school, :student_loans_eligible)
    visit new_claim_path(Journeys::TeacherStudentLoanReimbursement::ROUTING_NAME)
    skip_tid
    expect(page).to have_link("Back")
    choose_qts_year
    expect(page).to have_link("Back")
    choose_school school
    click_on "Back"
    expect(page).to have_current_path("/student-loans/claim-school", ignore_query: true)
    click_on "Back"
    expect(page).to have_text(I18n.t("student_loans.forms.qts_year.questions.qts_award_year"))
    click_on "Back"
    expect(page).to have_text("Use DfE Identity to sign in")
    expect(page).to have_link("Back")
    click_on "Back"
    expect(page).to have_text("Claim back student loan repayments if you're a teacher")
  end

  scenario "ECP/LUP journey" do
    create(:journey_configuration, :additional_payments)
    lup_school = create(:school, :levelling_up_premium_payments_eligible)

    visit new_claim_path(Journeys::AdditionalPaymentsForTeaching::ROUTING_NAME)
    # - Sign in or continue page
    expect(page).to have_text("Use DfE Identity to sign in")
    expect(page).to have_link("Back")
    click_on "Continue without signing in"

    expect(page).to have_link("Back")
    choose_school lup_school
    expect(page).to have_link("Back")

    # go to deadend
    choose "No"
    click_on "Continue"
    expect(page).to have_link("Back")
    choose "None of the above"
    click_on "Continue"
    choose "No"
    click_on "Continue"
    expect(page).to have_no_link("Back")
  end

  scenario "ECP/LUP trainee mini journey" do
    create(:journey_configuration, :additional_payments)
    lup_school = create(:school, :levelling_up_premium_payments_eligible)

    visit new_claim_path(Journeys::AdditionalPaymentsForTeaching::ROUTING_NAME)

    # - Sign in or continue page
    expect(page).to have_text("Use DfE Identity to sign in")
    expect(page).to have_link("Back")
    click_on "Continue without signing in"

    choose_school lup_school

    choose "No, I’m a trainee teacher"
    click_on "Continue"
    click_on "Back"

    expect(page).to have_link("Back")
  end
end
