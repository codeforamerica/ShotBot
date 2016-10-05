require 'rails_helper'

RSpec.describe Patient, type: :model do
  include PatientSpecHelper
  include AntigenImporterSpecHelper

  before do
    new_time = Time.local(2016, 1, 3, 10, 0, 0)
    Timecop.freeze(new_time)
  end

  after do
    Timecop.return
  end

  let(:patient_w_vaccines) do
    patient = FactoryGirl.create(:patient_with_profile,
                                 patient_profile_attributes: {
                                   dob: in_pst(5.years.ago),
                                   patient_number: 123
                                 })
    vaccine_types = %w(MCV6 DTaP MMR9)
    vaccine_types.each do |vax_code|
      create(:vaccine_dose,
             patient_profile: patient.patient_profile,
             vaccine_code: vax_code,
             date_administered: 2.years.ago.to_date)
      create(:vaccine_dose,
             patient_profile: patient.patient_profile,
             vaccine_code: vax_code,
             date_administered: 1.years.ago.to_date)
      create(:vaccine_dose,
             patient_profile: patient.patient_profile,
             vaccine_code: vax_code)
    end
    patient
  end

  describe '#create' do
    it 'automatically creates a User with the type \'Patient\'' do
      patient = Patient.create(first_name: 'Test', last_name: 'Tester')
      expect(User.last).to eq(patient)
      expect(User.last.type).to eq('Patient')
    end

    it 'allows patient_profile_attributes to be included in instantiation' do
      dob     = in_pst(Date.today)
      patient = Patient.create(
        first_name: 'Test', last_name: 'Tester',
        patient_profile_attributes: { dob: dob, patient_number: 123 }
      )
      expect(patient.dob).to eq(dob)
      expect(patient.patient_number).to eq(123)
      expect(patient.patient_profile.id).not_to eq(nil)
      expect(Patient.all.length).to eq(1)
    end

    it 'has a patient profile with the join on its uuid' do
      dob     = in_pst(Date.today)
      patient = Patient.create(
        first_name: 'Test', last_name: 'Tester',
        patient_profile_attributes: { dob: dob, patient_number: 123 }
      )
      expect(patient.patient_profile.patient_id).to eq(patient.id)
    end
  end
  describe '#validations' do
    it 'can take string dates and convert them to the database date object' do
      dob_string = '01/13/2010'
      patient    = Patient.create(
        first_name: 'Test', last_name: 'Tester',
        patient_profile_attributes: { dob: dob_string, patient_number: 123 }
      )
      dob_date_object = DateTime.parse(dob_string).to_date
      expect(patient.dob).to eq(dob_date_object)
    end
  end
  describe '#relationships' do
    it 'has many vaccine_doses' do
      dob     = in_pst(Date.today)
      patient = Patient.create(
        first_name: 'Test', last_name: 'Tester',
        patient_profile_attributes: { dob: dob, patient_number: 123 }
      )
      expect(patient.vaccine_doses.length).to eq(0)
      FactoryGirl.create(:vaccine_dose, patient: patient)
      expect(patient.vaccine_doses.length).to eq(1)
    end
    it 'has a dob attribute in years' do
      patient = FactoryGirl.create(:patient_with_profile, patient_profile_attributes: {
                                     dob: in_pst(5.years.ago),
                                     patient_number: 123
                                   })
      expect(patient.dob).to eq(5.years.ago.to_date)
    end
  end

  describe '#find_by_patient_number' do
    let(:test_patient) { FactoryGirl.create(:patient_with_profile) }

    it 'takes a string' do
      patient_number = test_patient.patient_number.to_s
      result = Patient.find_by_patient_number(patient_number)
      expect(result.id).to eq(test_patient.id)
    end

    it 'takes an integer' do
      patient_number = test_patient.patient_number.to_i
      result = Patient.find_by_patient_number(patient_number)
      expect(result.id).to eq(test_patient.id)
    end

    it 'returns nil when no patient is found' do
      result = Patient.find_by_patient_number('9876')
      expect(result).to eq(nil)
    end
  end
  xdescribe '#check_record' do
    let(:test_patients) { FactoryGirl.create_list(:patient, 10) }

    xit 'returns true if valid' do
      valid_imm = test_patients[0].check_record
      expect(valid_imm).to eq(true)
    end

    xit 'returns false if not_valid' do
      not_valid_patient = FactoryGirl.create(:patient_with_profile)
      not_valid_imm = not_valid_patient.check_record
      expect(not_valid_imm).to eq(false)
    end
  end
  describe '#age_in_days' do
    it 'returns the patients age in days' do
      patient = FactoryGirl.create(:patient_with_profile,
                                   patient_profile_attributes: {
                                     dob: in_pst(5.years.ago),
                                     patient_number: 123
                                   })
      days_age = patient.age_in_days
      expect(days_age).to eq((365 * 5) + 1)
    end
  end
  describe '#age' do
    let(:patient_5_years) do
      FactoryGirl.create(
        :patient,
        patient_profile_attributes: {
          dob: in_pst(5.years.ago),
          patient_number: 123
        }
      )
    end
    it 'returns the patients age in years' do
      pat_age = patient_5_years.age
      expect(pat_age).to eq(5)
    end

    it 'is still 5 years if born one day earlier' do
      new_date = patient_5_years.patient_profile.dob - 1
      patient_5_years.patient_profile.update(dob: new_date)
      pat_age = patient_5_years.age
      expect(pat_age).to eq(5)
    end

    it 'is 4 years if born one day later' do
      new_date = patient_5_years.patient_profile.dob + 1
      patient_5_years.patient_profile.update(dob: new_date)
      pat_age = patient_5_years.age
      expect(pat_age).to eq(4)
    end
  end

  describe '#get_vaccine_doses' do
    it 'returns all vaccines of the types passed in' do
      expect(patient_w_vaccines.get_vaccine_doses(%w(DTaP DTP)).length).to eq(3)
      expect(patient_w_vaccines.get_vaccine_doses(%w(DTaP DTP))[0].vaccine_code)
        .to eq('DTaP')
    end

    it 'returns all vaccines in the order of vaccine_dose date' do
      vax1, vax2, vax3 = patient_w_vaccines.get_vaccine_doses(%w(DTaP DTP))
      expect(vax1.date_administered < vax2.date_administered).to be(true)
      expect(vax1.date_administered < vax3.date_administered).to be(true)
      expect(vax2.date_administered < vax3.date_administered).to be(true)
    end

    it 'returns a blank array if no vaccines are present' do
      expect(patient_w_vaccines.get_vaccine_doses(['DTP']).length).to eq(0)
    end
  end

  describe '#antigen_administered_records' do
    before(:all) { seed_antigen_xml_polio }
    after(:all) { DatabaseCleaner.clean_with(:truncation) }

    let(:test_patient) do
      patient = FactoryGirl.create(:patient_with_profile,
                                   patient_profile_attributes: {
                                     dob: in_pst(5.years.ago),
                                     patient_number: 123
                                   })
      create(:vaccine_dose,
             patient_profile: patient.patient_profile,
             vaccine_code: 'POL',
             date_administered: 2.years.ago.to_date)
      create(:vaccine_dose,
             patient_profile: patient.patient_profile,
             vaccine_code: 'POL',
             date_administered: 1.years.ago.to_date)
      create(:vaccine_dose,
             patient_profile: patient.patient_profile,
             vaccine_code: 'POL')
      patient
    end

    it 'creates antigen_administered_records when called' do
      expect(test_patient.vaccine_doses).not_to eq([])
      expect(test_patient.antigen_administered_records.first.class.name)
        .to eq('AntigenAdministeredRecord')
    end
    it 'can access the objects multiple times' do
      expect(test_patient.vaccine_doses).not_to eq([])
      expect(test_patient.antigen_administered_records)
        .to be(test_patient.antigen_administered_records)
    end
  end

  describe 'record_evaluator methods' do
    before(:all) do
      seed_full_antigen_xml
    end
    after(:all) do
      DatabaseCleaner.clean_with(:truncation)
    end
    describe '#evaluate_record' do
      it 'creates a record_evaluator object' do
        test_patient           = valid_2_year_test_patient
        first_record_evaluator = test_patient.record_evaluator

        expect(test_patient.record_evaluator.object_id)
          .to eq(first_record_evaluator.object_id)

        test_patient.evaluate_record

        expect(test_patient.record_evaluator.object_id)
          .not_to eq(first_record_evaluator.object_id)

        expect(test_patient.record_evaluator.object_id)
          .to eq(test_patient.record_evaluator.object_id)
      end
    end
    describe '#evaluation_status' do
      it 'evaluates complete for a valid 2 year olds record' do
        test_patient = valid_2_year_test_patient
        expect(test_patient.evaluation_status).to eq('complete')
      end
      it 'evaluates not_complete for a invalid 2 year olds record' do
        test_patient = invalid_2_year_test_patient
        expect(test_patient.evaluation_status).to eq('not_complete')
      end
      it 'evaluates complete for a valid 5 year olds record' do
        test_patient = valid_5_year_test_patient
        expect(test_patient.evaluation_status).to eq('complete')
      end
      it 'evaluates not_complete for a invalid 5 year olds record' do
        test_patient = invalid_5_year_test_patient
        expect(test_patient.evaluation_status).to eq('not_complete')
      end
    end
    describe '#evaluation_details' do
      it 'returns all required complete for a valid 2 year olds record' do
        test_patient = valid_2_year_test_patient
        expect(test_patient.evaluation_details).to eq('complete')
      end
      it 'returns required not_complete for a invalid 2 year olds record' do
        test_patient = invalid_2_year_test_patient
        expect(test_patient.evaluation_details).to eq('not_complete')
      end
      it 'returns all required complete for a valid 5 year olds record' do
        test_patient = valid_5_year_test_patient
        expect(test_patient.evaluation_details).to eq('complete')
      end
      it 'returns required not_complete for a invalid 5 year olds record' do
        test_patient = invalid_5_year_test_patient
        expect(test_patient.evaluation_details).to eq('not_complete')
      end
    end
  end
end
