module Policies
  module LevellingUpPremiumPayments
    class Eligibility < ApplicationRecord
      include EligibilityCheckable
      include ActiveSupport::NumberHelper

      self.table_name = "levelling_up_premium_payments_eligibilities"
      has_one :claim, as: :eligibility, inverse_of: :eligibility
      belongs_to :current_school, optional: true, class_name: "School"

      validate :award_amount_must_be_in_range, on: :amendment

      delegate :name, to: :current_school, prefix: true, allow_nil: true

      AMENDABLE_ATTRIBUTES = [:award_amount].freeze

      ATTRIBUTE_DEPENDENCIES = {
        "employed_as_supply_teacher" => ["has_entire_term_contract", "employed_directly"],
        "qualification" => ["eligible_itt_subject", "teaching_subject_now"],
        "eligible_itt_subject" => ["teaching_subject_now", "eligible_degree_subject"],
        "itt_academic_year" => ["eligible_itt_subject"]
      }.freeze

      FIRST_ITT_AY = "2017/2018"
      LAST_POLICY_YEAR = "2024/2025"

      # Generates an object similar to
      # {
      #   <AcademicYear:0x00007f7d87429238 @start_year=2020, @end_year=2021> => "2020/2021",
      #   <AcademicYear:0x00007f7d87429210 @start_year=2021, @end_year=2022> => "2021/2022",
      #   <AcademicYear:0x00007f7d87428c98 @start_year=nil, @end_year=nil> => "None"
      # }
      # Note: LUPP policy began in academic year 2022/23 so the persisted options
      # should include 2017/18 onward.
      # In test environment the journey configuration record may not exist.
      # This can't be dynamic on Journeys::Configuration current_academic_year because changing the year means the 5 year window changes
      # and the enums would be stale until after a server restart.
      # Make all valid ITT values based on the last known policy year.
      ITT_ACADEMIC_YEARS =
        (AcademicYear.new(FIRST_ITT_AY)...AcademicYear.new(LAST_POLICY_YEAR)).each_with_object({}) do |year, hsh|
          hsh[year] = AcademicYear::Type.new.serialize(year)
        end.merge({AcademicYear.new => AcademicYear::Type.new.serialize(AcademicYear.new)})

      enum itt_academic_year: ITT_ACADEMIC_YEARS

      enum qualification: {
        postgraduate_itt: 0,
        undergraduate_itt: 1,
        assessment_only: 2,
        overseas_recognition: 3
      }

      enum eligible_itt_subject: {
        chemistry: 0,
        foreign_languages: 1,
        mathematics: 2,
        physics: 3,
        none_of_the_above: 4,
        computing: 5
      }, _prefix: :itt_subject

      def policy
        Policies::LevellingUpPremiumPayments
      end

      def award_amount
        super || BigDecimal(calculate_award_amount || 0)
      end

      def reset_dependent_answers(reset_attrs = [])
        attrs = ineligible? ? changed.concat(reset_attrs) : changed

        dependencies = ATTRIBUTE_DEPENDENCIES.dup

        # If some data was derived from DQT we do not want to reset these.
        if claim.qualifications_details_check
          dependencies.delete("qualification")
          dependencies.delete("eligible_itt_subject")
          dependencies.delete("itt_academic_year")
        end

        dependencies.each do |attribute_name, dependent_attribute_names|
          dependent_attribute_names.each do |dependent_attribute_name|
            write_attribute(dependent_attribute_name, nil) if attrs.include?(attribute_name)
          end
        end
      end

      def indicated_ineligible_itt_subject?
        return false if eligible_itt_subject.blank?

        args = {claim_year: claim_year, itt_year: itt_academic_year}

        if args.values.any?(&:blank?)
          # trainee teacher who won't have given their ITT year
          eligible_itt_subject.present? && !eligible_itt_subject.to_sym.in?(JourneySubjectEligibilityChecker.fixed_lup_subject_symbols)
        else
          itt_subject_checker = JourneySubjectEligibilityChecker.new(**args)
          eligible_itt_subject.present? && !eligible_itt_subject.to_sym.in?(itt_subject_checker.current_subject_symbols(policy))
        end
      end

      def calculate_award_amount
        premium_payment_award&.award_amount
      end

      private

      def premium_payment_award
        return unless current_school.present?

        current_school.levelling_up_premium_payments_awards.find_by(
          academic_year: claim_year.to_s
        )
      end

      def indicated_ecp_only_itt_subject?
        eligible_itt_subject.present? && (eligible_itt_subject.to_sym == :foreign_languages)
      end

      def specific_eligible_now_attributes?
        eligible_itt_subject_or_relevant_degree?
      end

      def eligible_itt_subject_or_relevant_degree?
        good_itt_subject? || eligible_degree?
      end

      def good_itt_subject?
        return false if eligible_itt_subject.blank?

        args = {claim_year: claim_year, itt_year: itt_academic_year}

        if args.values.any?(&:blank?)
          # trainee teacher who won't have given their ITT year
          eligible_itt_subject.present? && eligible_itt_subject.to_sym.in?(JourneySubjectEligibilityChecker.fixed_lup_subject_symbols)
        else
          itt_subject_checker = JourneySubjectEligibilityChecker.new(**args)
          eligible_itt_subject.to_sym.in?(itt_subject_checker.current_subject_symbols(policy))
        end
      end

      def eligible_degree?
        eligible_degree_subject?
      end

      def specific_ineligible_attributes?
        indicated_ecp_only_itt_subject? || trainee_teacher_with_ineligible_itt_subject? || ineligible_itt_subject_and_no_relevant_degree?
      end

      def trainee_teacher_with_ineligible_itt_subject?
        trainee_teacher? && indicated_ineligible_itt_subject?
      end

      def ineligible_itt_subject_and_no_relevant_degree?
        indicated_ineligible_itt_subject? && lacks_eligible_degree?
      end

      def specific_eligible_later_attributes?
        trainee_teacher? && eligible_itt_subject_or_relevant_degree?
      end

      def lacks_eligible_degree?
        eligible_degree_subject == false
      end

      def award_amount_must_be_in_range
        max = LevellingUpPremiumPayments::Award.where(academic_year: claim_year.to_s).maximum(:award_amount)

        unless award_amount.between?(1, max)
          errors.add(:award_amount, "Enter a positive amount up to #{number_to_currency(max)} (inclusive)")
        end
      end
    end
  end
end
