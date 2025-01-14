# frozen_string_literal: true

require "rails_helper"

RSpec.describe Policies::StudentLoans::Eligibility, type: :model do
  let(:eligible_school) { build(:school, :student_loans_eligible) }
  let(:ineligible_school) { build(:school, :student_loans_ineligible) }

  describe "qts_award_year attribute" do
    it "rejects invalid values" do
      expect { described_class.new(qts_award_year: "non-existence") }.to raise_error(ArgumentError)
    end

    it "has handily named boolean methods for the possible values" do
      eligibility = described_class.new(qts_award_year: "on_or_after_cut_off_date")

      expect(eligibility.awarded_qualified_status_on_or_after_cut_off_date?).to eq true
      expect(eligibility.awarded_qualified_status_before_cut_off_date?).to eq false
    end
  end

  describe "employment_status attribute" do
    it "rejects invalid values" do
      expect { described_class.new(employment_status: "non-existence") }.to raise_error(ArgumentError)
    end

    it "has handily named boolean methods for the possible values" do
      eligibility = described_class.new(employment_status: :claim_school)

      expect(eligibility.employed_at_claim_school?).to eq true
      expect(eligibility.employed_at_different_school?).to eq false
    end
  end

  describe "student_loan_repayment_amount attribute" do
    it "validates that the loan repayment amount is numerical" do
      expect(described_class.new(student_loan_repayment_amount: "don’t know")).not_to be_valid
      expect(described_class.new(student_loan_repayment_amount: "£1,234.56")).not_to be_valid
    end

    it "validates that the loan repayment is under £99,999" do
      expect(described_class.new(student_loan_repayment_amount: 100_000)).not_to be_valid
      expect(described_class.new(student_loan_repayment_amount: 99_999)).to be_valid
    end

    it "validates that the loan repayment is greater than or equal to zero" do
      expect(described_class.new(student_loan_repayment_amount: "-99")).not_to be_valid
      expect(described_class.new(student_loan_repayment_amount: "0")).to be_valid
      expect(described_class.new(student_loan_repayment_amount: "150")).to be_valid
    end

    it "validates that the loan repayment less than £5000 when amending a claim" do
      expect(described_class.new(student_loan_repayment_amount: "5001")).not_to be_valid(:amendment)
      expect(described_class.new(student_loan_repayment_amount: "1200")).to be_valid(:amendment)
    end
  end

  describe "#claim_school_name" do
    it "returns the name of the claim school" do
      eligibility = described_class.new(claim_school: eligible_school)
      expect(eligibility.claim_school_name).to eq eligible_school.name
    end

    it "does not error if the claim school is not set" do
      expect(described_class.new.claim_school_name).to be_nil
    end
  end

  describe "#current_school_name" do
    it "returns the name of the current school" do
      claim = described_class.new(current_school: eligible_school)
      expect(claim.current_school_name).to eq eligible_school.name
    end

    it "does not error if the current school is not set" do
      expect(described_class.new.current_school_name).to be_nil
    end
  end

  describe "#subjects_taught" do
    it "returns an array of the subject attributes that are true" do
      expect(described_class.new.subjects_taught).to eq []
      expect(described_class.new(biology_taught: true, physics_taught: true, chemistry_taught: false).subjects_taught).to eq [:biology_taught, :physics_taught]
    end
  end

  describe "#ineligible?" do
    it "returns false when the eligibility cannot be determined" do
      expect(described_class.new.ineligible?).to eql false
    end

    it "returns true when the qts_award_year is before the qualifying cut-off" do
      expect(described_class.new(qts_award_year: "before_cut_off_date").ineligible?).to eql true
      expect(described_class.new(qts_award_year: "on_or_after_cut_off_date").ineligible?).to eql false
    end

    describe "claim_school eligibility" do
      subject(:eligibility) { described_class.new(claim_school: school) }

      context "when the claim_school is not eligible" do
        let(:school) { ineligible_school }

        it { is_expected.to be_ineligible }
      end

      context "when the claim_school is eligible" do
        let(:school) { eligible_school }

        it { is_expected.not_to be_ineligible }
      end
    end

    describe "current_school eligibility" do
      subject(:eligibility) { described_class.new(current_school: school) }

      context "when the current_school is not eligible" do
        let(:school) { ineligible_school }

        it { is_expected.to be_ineligible }
      end

      context "when the claim_school is eligible" do
        let(:school) { eligible_school }

        it { is_expected.not_to be_ineligible }
      end
    end

    it "returns true when no longer teaching" do
      expect(described_class.new(employment_status: :no_school).ineligible?).to eql true
      expect(described_class.new(employment_status: :claim_school).ineligible?).to eql false
    end

    it "returns true when not teaching an eligible subject" do
      expect(described_class.new(taught_eligible_subjects: false).ineligible?).to eql true
      expect(described_class.new(biology_taught: true).ineligible?).to eql false
    end

    it "returns true when more than half time is spent performing leadership duties" do
      expect(described_class.new(mostly_performed_leadership_duties: true).ineligible?).to eql true
      expect(described_class.new(mostly_performed_leadership_duties: false).ineligible?).to eql false
    end

    context "student_loan_repayment_amount eligibility" do
      subject(:eligibility) { described_class.new(student_loan_repayment_amount: 0, claim:) }

      context "when the has_student_loan claim flag is true" do
        let(:claim) { build(:claim, has_student_loan: true) }

        it { is_expected.to be_ineligible }
      end

      context "when the has_student_loan claim flag is false" do
        let(:claim) { build(:claim, has_student_loan: false) }

        it { is_expected.not_to be_ineligible }
      end

      context "when the has_student_loan claim flag is nil" do
        let(:claim) { build(:claim, has_student_loan: nil) }

        it { is_expected.not_to be_ineligible }
      end
    end
  end

  describe "#ineligibility_reason" do
    it "returns nil when the reason for ineligibility cannot be determined" do
      expect(described_class.new.ineligibility_reason).to be_nil
    end

    it "returns a symbol indicating the reason for ineligibility" do
      expect(described_class.new(qts_award_year: "before_cut_off_date").ineligibility_reason).to eq :ineligible_qts_award_year
      expect(described_class.new(claim_school: ineligible_school).ineligibility_reason).to eq :ineligible_claim_school
      expect(described_class.new(employment_status: :no_school).ineligibility_reason).to eq :employed_at_no_school
      expect(described_class.new(current_school: ineligible_school).ineligibility_reason).to eq :ineligible_current_school
      expect(described_class.new(taught_eligible_subjects: false).ineligibility_reason).to eq :not_taught_eligible_subjects
      expect(described_class.new(mostly_performed_leadership_duties: true).ineligibility_reason).to eq :not_taught_enough
      expect(described_class.new(student_loan_repayment_amount: 0, claim: Claim.new(has_student_loan: true)).ineligibility_reason).to eq :made_zero_repayments
    end
  end

  describe "#award_amount" do
    it "returns the student loan repayment amount" do
      eligibility = described_class.new(student_loan_repayment_amount: 1000)
      expect(eligibility.award_amount).to eq(1000)
    end
  end

  describe "#reset_dependent_answers" do
    let(:eligibility) do
      create(
        :student_loans_eligibility,
        :eligible,
        claim_school: build(:school, :student_loans_eligible),
        current_school: build(:school, :student_loans_eligible),
        taught_eligible_subjects: true,
        chemistry_taught: true,
        physics_taught: true,
        computing_taught: true,
        languages_taught: true,
        employment_status: :different_school,
        had_leadership_position: true
      )
    end

    it "resets employment_status when the value of claim_school changes" do
      eligibility.claim_school = eligibility.claim_school # standard:disable Lint/SelfAssignment
      expect { eligibility.reset_dependent_answers }.not_to change { eligibility.attributes }

      eligibility.claim_school = eligibility.current_school
      expect { eligibility.reset_dependent_answers }
        .to change { eligibility.employment_status }
        .from("different_school").to(nil)
    end

    it "resets the current_school_id to nil when the value of claim_school changes" do
      expect { eligibility.reset_dependent_answers }.not_to change { eligibility.attributes }

      eligibility.claim_school = eligibility.current_school
      expect { eligibility.reset_dependent_answers }
        .to change { eligibility.current_school_id }
        .from(eligibility.current_school.id).to(nil)
    end

    it "resets the subject fields when the value of the claim_school changes" do
      eligibility.claim_school = eligibility.current_school
      eligibility.reset_dependent_answers

      expect(eligibility.taught_eligible_subjects).to eq(nil)
      expect(eligibility.physics_taught).to eq(nil)
      expect(eligibility.chemistry_taught).to eq(nil)
      expect(eligibility.physics_taught).to eq(nil)
      expect(eligibility.computing_taught).to eq(nil)
      expect(eligibility.languages_taught).to eq(nil)
    end

    it "resets mostly_performed_leadership_duties when the value of had_leadership_position changes" do
      eligibility.had_leadership_position = true
      expect { eligibility.reset_dependent_answers }.not_to change { eligibility.attributes }

      eligibility.had_leadership_position = false
      expect { eligibility.reset_dependent_answers }
        .to change { eligibility.mostly_performed_leadership_duties }
        .from(false).to(nil)
    end
  end

  context "when saving in the “submit” context" do
    it "is valid when all attributes are present" do
      expect(build(:student_loans_eligibility, :eligible)).to be_valid(:submit)
    end

    it "is not valid without a value for employment_status" do
      expect(build(:student_loans_eligibility, :eligible, employment_status: nil)).not_to be_valid(:submit)
    end

    it "is not valid without a value for student_loan_repayment_amount" do
      expect(build(:student_loans_eligibility, student_loan_repayment_amount: nil)).not_to be_valid(:submit)
    end
  end

  describe "#eligible_itt_subject" do
    it "returns nil" do
      expect(described_class.new.eligible_itt_subject).to be(nil)
    end
  end

  describe "#ineligible_qts_award_year?" do
    subject { described_class.new(qts_award_year:).ineligible_qts_award_year? }

    context "when the qts award year is eligibile" do
      let(:qts_award_year) { "on_or_after_cut_off_date" }

      it { is_expected.to eq(false) }
    end

    context "when the qts award year is not eligible" do
      let(:qts_award_year) { "before_cut_off_date" }

      it { is_expected.to eq(true) }
    end
  end
end
