class CreateVaccineRequirementDetails < ActiveRecord::Migration
  def change
    create_table :vaccine_requirement_details do |t|
      t.integer :requirer_id
      t.integer :requirement_id
      t.integer :required_years, default: 0
      t.integer :required_months, default: 0
      t.integer :required_weeks, default: 0

      t.timestamps null: false
    end
  end
end