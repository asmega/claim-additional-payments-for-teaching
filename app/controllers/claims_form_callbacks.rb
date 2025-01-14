module ClaimsFormCallbacks
  def current_school_before_show
    set_backlink_override_to_current_slug if on_school_search_results?
  end

  def claim_school_before_show
    set_backlink_override_to_current_slug if on_school_search_results?
  end

  def teaching_subject_now_before_show
    redirect_to_slug("eligible-itt-subject") if no_eligible_itt_subject?
  end

  def qualification_details_before_show
    redirect_to_next_slug if no_dqt_data?
  end

  def address_before_show
    set_backlink_override(slug: "postcode-search") if no_postcode?
  end

  def select_home_address_before_show
    set_backlink_override(slug: "postcode-search")
  end

  def personal_bank_account_before_update
    inject_hmrc_validation_attempt_count_into_the_form
  end

  def building_society_account_before_update
    inject_hmrc_validation_attempt_count_into_the_form
  end

  def information_provided_before_update
    return unless journey_requires_student_loan_details?

    retrieve_student_loan_details if on_tid_route?
  end

  def personal_details_after_form_save_success
    return unless journey_requires_student_loan_details?

    retrieve_student_loan_details
    redirect_to_next_slug
  end

  def eligibility_confirmed_after_form_save_success
    update_session_with_selected_policy if additional_payments_journey?
    redirect_to_next_slug
  end

  def personal_bank_account_after_form_save_failure
    increment_hmrc_validation_attempt_count if hmrc_api_validation_attempted?
    render_template_for_current_slug
  end

  def building_society_account_after_form_save_failure
    increment_hmrc_validation_attempt_count if hmrc_api_validation_attempted?
    render_template_for_current_slug
  end

  def postcode_search_after_form_save_failure
    lookup_failed_error = @form.errors.messages_for(:base).first
    if lookup_failed_error
      flash[:notice] = lookup_failed_error
      redirect_to_slug("address")
    else
      render_template_for_current_slug
    end
  end

  private

  def set_backlink_override_to_current_slug
    set_backlink_override(slug: current_slug)
  end

  def set_backlink_override(slug:)
    @backlink_path = claim_path(current_journey_routing_name, slug) if page_sequence.in_sequence?(slug)
  end

  def on_school_search_results?
    params[:school_search]&.present?
  end

  def no_eligible_itt_subject?
    !current_claim.eligible_itt_subject
  end

  def no_dqt_data?
    journey_session.answers.has_no_dqt_data_for_claim?
  end

  def no_postcode?
    !current_claim.postcode
  end

  def update_session_with_selected_policy
    # TODO: revisit this once the claimant's answers are all moved to the session, as at
    # that point we can probably encapsulate this behaviour somewhere else
    session[:selected_claim_policy] = @form.selected_claim_policy
  end

  def retrieve_student_loan_details
    # FIXME RL: The ClaimStudentLoanDetailsUpdater is called from a
    # background job that runs against submitted claims making it tricky to
    # pass in the journey_session.answers, so we set the attributes on the
    # current_claim from the session answers here.
    # To be addressed in
    # https://dfedigital.atlassian.net.mcas.ms/browse/CAPT-1697
    current_claim.national_insurance_number = journey_session.answers.national_insurance_number
    current_claim.date_of_birth = journey_session.answers.date_of_birth
    ClaimStudentLoanDetailsUpdater.call(current_claim)
  end

  def hmrc_api_validation_attempted?
    @form&.hmrc_api_validation_attempted?
  end

  def inject_hmrc_validation_attempt_count_into_the_form
    params[:claim][:hmrc_validation_attempt_count] = current_hmrc_validation_attempt_count
  end

  def increment_hmrc_validation_attempt_count
    session[:hmrc_validation_attempt_count] = current_hmrc_validation_attempt_count + 1
  end

  def current_hmrc_validation_attempt_count
    session[:hmrc_validation_attempt_count] || 0
  end

  def on_tid_route?
    journey_session.answers.logged_in_with_tid? && journey_session.answers.all_personal_details_same_as_tid?
  end

  def journey_requires_student_loan_details?
    student_loans_journey? || additional_payments_journey?
  end

  def student_loans_journey?
    current_journey_routing_name == "student-loans"
  end

  def additional_payments_journey?
    current_journey_routing_name == "additional-payments"
  end
end
