module Journeys
  module AdditionalPaymentsForTeaching
    module Reminders
      class PersonalDetailsForm < Form
        attribute :full_name
        attribute :email_address

        validates :full_name, presence: {message: i18n_error_message(:"full_name.blank")}
        validates :full_name, length: {maximum: 100, message: i18n_error_message(:"full_name.length")}

        validates :email_address, presence: {message: i18n_error_message(:"email_address.blank")}
        validates :email_address, format: {with: Rails.application.config.email_regexp, message: i18n_error_message(:"email_address.invalid")},
          length: {maximum: 256, message: i18n_error_message(:"email_address.length")}, if: -> { email_address.present? }

        def self.model_name
          ActiveModel::Name.new(Form)
        end

        def save
          return false unless valid?

          update!(attributes)
        end

        private

        def i18n_form_namespace
          "reminders.#{super}"
        end
      end
    end
  end
end
