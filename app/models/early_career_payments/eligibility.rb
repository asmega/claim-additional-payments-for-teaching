module EarlyCareerPayments
  class Eligibility < ApplicationRecord
    EDITABLE_ATTRIBUTES = [
      :nqt_in_academic_year_after_itt,
      :employed_as_supply_teacher,
      :has_entire_term_contract,
      :employed_directly,
      :subject_to_disciplinary_action,
      :pgitt_or_ugitt_course,
      :eligible_itt_subject,
      :teaching_subject_now,
      :itt_academic_year
    ].freeze
    AMENDABLE_ATTRIBUTES = [].freeze
    ATTRIBUTE_DEPENDENCIES = {
      "employed_as_supply_teacher" => ["has_entire_term_contract", "employed_directly"],
      "pgitt_or_ugitt_course" => ["eligible_itt_subject", "teaching_subject_now"],
      "eligible_itt_subject" => ["teaching_subject_now"]
    }.freeze

    self.table_name = "early_career_payments_eligibilities"

    enum pgitt_or_ugitt_course: {
      postgraduate: 0,
      undergraduate: 1
    }, _suffix: :itt_course

    enum eligible_itt_subject: {
      chemistry: 0,
      mathematics: 1,
      modern_foreign_languages: 2,
      physics: 3,
      none_of_the_above: 4
    }, _prefix: :itt_subject

    enum itt_academic_year: {
      "2018_2019": 0,
      "2019_2020": 1,
      "2020_2021": 2,
      none_of_the_above: 3
    }, _prefix: :itt_academic_year

    has_one :claim, as: :eligibility, inverse_of: :eligibility

    validates :nqt_in_academic_year_after_itt, on: [:"nqt-in-academic-year-after-itt", :submit], inclusion: {in: [true, false], message: "Select yes if you did your NQT in the academic year after your ITT"}
    validates :employed_as_supply_teacher, on: [:"supply-teacher", :submit], inclusion: {in: [true, false], message: "Select yes if you are currently employed as a supply teacher"}
    validates :has_entire_term_contract, on: [:"entire-term-contract", :submit], inclusion: {in: [true, false], message: "Select yes if you have a contract to teach at the same school for one term or longer"}, if: :employed_as_supply_teacher?
    validates :employed_directly, on: [:"employed-directly", :submit], inclusion: {in: [true, false], message: "Select yes if you are employed directly by your school"}, if: :employed_as_supply_teacher?
    validates :subject_to_disciplinary_action, on: [:"disciplinary-action", :submit], inclusion: {in: [true, false], message: "Select yes if you are subject to disciplinary action"}
    validates :pgitt_or_ugitt_course, on: [:"postgraduate-itt-or-undergraduate-itt-course", :submit], presence: {message: "Select postgraduate if you did a Postgraduate ITT course"}
    validates :eligible_itt_subject, on: [:"eligible-itt-subject", :submit], presence: {message: "Select if you completed your initial teacher training in Chemistry, Mathematics, Modern Foreign Languages, Physics or None of these subjects"}
    validates :teaching_subject_now, on: [:"teaching-subject-now", :submit], inclusion: {in: [true, false], message: "Select yes if you are currently teaching in your ITT subject now"}
    validates :itt_academic_year, on: [:"itt-year", :submit], presence: {message: "Select if you started your initial teacher training in 2018 - 2019, 2019 - 2020, 2020 - 2021 or None of these academic years"}

    def policy
      EarlyCareerPayments
    end

    def ineligible?
      ineligible_nqt_in_academic_year_after_itt? ||
        no_entire_term_contract? ||
        not_employed_directly? ||
        subject_to_disciplinary_action? ||
        not_supported_itt_subject? ||
        not_teaching_now_in_eligible_itt_subject? ||
        ineligible_itt_academic_year?
    end

    def award_amount
      BigDecimal("2000.00")
    end

    def reset_dependent_answers
      ATTRIBUTE_DEPENDENCIES.each do |attribute_name, dependent_attribute_names|
        dependent_attribute_names.each do |dependent_attribute_name|
          write_attribute(dependent_attribute_name, nil) if changed.include?(attribute_name)
        end
      end
    end

    private

    def ineligible_nqt_in_academic_year_after_itt?
      nqt_in_academic_year_after_itt == false
    end

    def ineligible_itt_academic_year?
      itt_academic_year == "none_of_the_above"
    end

    def no_entire_term_contract?
      employed_as_supply_teacher? && has_entire_term_contract == false
    end

    def not_employed_directly?
      employed_as_supply_teacher? && employed_directly == false
    end

    def not_supported_itt_subject?
      itt_subject_none_of_the_above?
    end

    def not_teaching_now_in_eligible_itt_subject?
      teaching_subject_now == false
    end
  end
end