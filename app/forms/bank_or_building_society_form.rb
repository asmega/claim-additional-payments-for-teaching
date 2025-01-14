class BankOrBuildingSocietyForm < Form
  attribute :bank_or_building_society

  validates :bank_or_building_society,
    inclusion: {
      in: Claim.bank_or_building_societies.keys,
      message: i18n_error_message(:select_bank_or_building_society)
    }

  def save
    return false unless valid?

    claim.assign_attributes(bank_or_building_society:)
    claim.reset_dependent_answers
    claim.save!
  end
end
