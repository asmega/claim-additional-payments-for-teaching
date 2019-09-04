class BackfillFirstMiddleSurnames < ActiveRecord::Migration[5.2]
  def up
    claims_with_full_names.each do |claim|
      parser = Claim::VerifyResponseParametersParser.new(claim.verify_response)
      claim.update!(
        first_name: parser.first_name,
        middle_name: parser.middle_name,
        surname: parser.surname
      )
    end
  end

  def down
    claims_with_full_names.update_all(
      first_name: nil,
      middle_name: nil,
      surname: nil
    )
  end

  private

  def claims_with_full_names
    Claim.where.not(verify_response: nil).where.not(full_name: nil)
  end
end