require "rails_helper"

module TestPolicy
  include BasePolicy

  extend self
end

RSpec.describe BasePolicy, type: :model do
  describe "::policy_type" do
    it do
      expect(TestPolicy.policy_type).to eq("test-policy")
    end
  end

  describe "::short_name" do
    before do
      allow(I18n).to receive(:t)
    end

    it do
      TestPolicy.short_name

      expect(I18n).to have_received(:t).with("test_policy.policy_short_name")
    end
  end

  describe "::locale_key" do
    it do
      expect(TestPolicy.locale_key).to eq("test_policy")
    end
  end

  describe "::routing_name" do
    before do
      allow(PolicyConfiguration).to receive(:routing_name_for_policy)
    end

    it do
      TestPolicy.routing_name

      expect(PolicyConfiguration).to have_received(:routing_name_for_policy)
        .with(TestPolicy)
    end
  end

  describe "::configuration" do
    before do
      allow(PolicyConfiguration).to receive(:for)
    end

    it do
      TestPolicy.configuration

      expect(PolicyConfiguration).to have_received(:for).with(TestPolicy)
    end
  end
end