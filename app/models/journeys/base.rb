module Journeys
  module Base
    SHARED_FORMS = {
      "claims" => {
        "sign-in-or-continue" => SignInOrContinueForm,
        "current-school" => CurrentSchoolForm,
        "gender" => GenderForm,
        "personal-details" => PersonalDetailsForm,
        "select-email" => SelectEmailForm,
        "provide-mobile-number" => ProvideMobileNumberForm,
        "select-mobile" => SelectMobileForm,
        "email-address" => EmailAddressForm,
        "email-verification" => EmailVerificationForm,
        "mobile-number" => MobileNumberForm,
        "mobile-verification" => MobileVerificationForm,
        "bank-or-building-society" => BankOrBuildingSocietyForm,
        "personal-bank-account" => BankDetailsForm,
        "building-society-account" => BankDetailsForm,
        "teacher-reference-number" => TeacherReferenceNumberForm,
        "address" => AddressForm,
        "select-home-address" => SelectHomeAddressForm,
        "check-your-answers" => CheckYourAnswersForm
      }
    }.freeze

    def configuration
      Configuration.find(self::ROUTING_NAME)
    end

    def start_page_url
      slug_sequence.start_page_url
    end

    def slug_sequence
      self::SlugSequence
    end

    def form(claim:, journey_session:, params:)
      form = SHARED_FORMS.deep_merge(forms).dig(params[:controller].split("/").last, params[:slug])

      form&.new(journey: self, journey_session:, claim:, params:)
    end

    def forms
      defined?(self::FORMS) ? self::FORMS : {}
    end

    def page_sequence_for_claim(claim, journey_session, completed_slugs, current_slug)
      PageSequence.new(
        claim,
        slug_sequence.new(claim, journey_session),
        completed_slugs,
        current_slug,
        journey_session
      )
    end

    def answers_presenter
      self::AnswersPresenter
    end

    def answers_for_claim(claim, journey_session)
      answers_presenter.new(claim, journey_session)
    end
  end
end
