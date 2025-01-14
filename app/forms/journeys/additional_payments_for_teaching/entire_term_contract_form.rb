module Journeys
  module AdditionalPaymentsForTeaching
    class EntireTermContractForm < Form
      attribute :has_entire_term_contract, :boolean

      validates :has_entire_term_contract, inclusion: {in: [true, false], message: i18n_error_message(:inclusion)}

      def save
        return false unless valid?

        update!(eligibility_attributes: attributes)
      end
    end
  end
end
