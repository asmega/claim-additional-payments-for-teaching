module StubbingHelpers
  def disable_claim_qa_flagging
    stub_const("Claim::MIN_QA_THRESHOLD", 0)
  end

  def stub_otp_verification(otp_code:, valid: true)
    allow_any_instance_of(NotifySmsMessage).to receive(:deliver!)
    allow_any_instance_of(OneTimePassword::Generator).to receive(:code).and_return(otp_code)
    allow_any_instance_of(OneTimePassword::Validator).to receive(:valid?).and_return(valid)
  end
end
