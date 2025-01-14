require "rails_helper"

RSpec.feature "Claim journey does not get cached" do
  before { create(:journey_configuration, :student_loans) }

  it "redirects the user to the start of the claim journey if they go back after the claim is completed" do
    claim = start_student_loans_claim
    claim.update!(attributes_for(:claim, :submittable))
    journey_session = Journeys::TeacherStudentLoanReimbursement::Session.last
    journey_session.update!(
      answers: attributes_for(
        :student_loans_answers,
        :with_details_from_dfe_identity,
        :with_email_details
      )
    )
    claim.eligibility = create(:student_loans_eligibility, :eligible)
    claim.save!

    jump_to_claim_journey_page(claim, "check-your-answers")

    expect(page).to have_text(claim.first_name)

    click_on "Confirm and send"

    expect(current_path).to eq(claim_confirmation_path(Journeys::TeacherStudentLoanReimbursement::ROUTING_NAME))

    jump_to_claim_journey_page(claim, "check-your-answers")

    expect(page).to_not have_text(claim.first_name)
    expect(page).to have_text("Use DfE Identity to sign in")
  end
end
