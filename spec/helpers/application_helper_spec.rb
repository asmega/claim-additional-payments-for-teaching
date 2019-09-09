require "rails_helper"

describe ApplicationHelper do
  describe "#currency_value_for_number_field" do
    let(:value) { 1000.1 }

    it "formats the number to two decimal places and is suitable for a number_field" do
      expect(helper.currency_value_for_number_field(value)).to eql("1000.10")
    end

    context "when no value exists" do
      let(:value) { nil }

      it "does no formatting and just returns nil" do
        expect(helper.currency_value_for_number_field(value)).to be_nil
      end
    end
  end

  describe "page_title" do
    it "Returns a title without an error prefix" do
      page_title("Some Title", show_error: false)
      title = content_for(:page_title)

      expect(title).to eq("Some Title - #{I18n.t("student_loans.journey_name")} - GOV.UK")
    end

    it "Returns an error prefix" do
      page_title("Some Title", show_error: true)
      title = content_for(:page_title)

      expect(title).to eq("Error - Some Title - #{I18n.t("student_loans.journey_name")} - GOV.UK")
    end
  end
end
