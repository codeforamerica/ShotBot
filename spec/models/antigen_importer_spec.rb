require 'rails_helper'
require_relative '../support/antigen_xml'

RSpec.describe AntigenImporter, type: :model do
  include AntigenImporterSpecHelper
  describe '#create' do
    it 'takes no arguments to instantiate' do
      antigen_importer = AntigenImporter.new
      expect(antigen_importer.class.name).to eq('AntigenImporter')
    end
  end

  describe '#xml_to_hash' do
    it 'takes an xml string and returns a hash' do
      xml_string = TestAntigen::ANTIGENSTRING
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash.class.name).to eq('Hash')
    end
    it 'has the first level xml tag as the top level key' do
      xml_string = '<testXML><levelOne><level2></level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash.has_key?('testXML')).to be_truthy
    end
    it 'uses key strings as lookups and not symbols' do
      xml_string = '<testXML><levelOne><level2></level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash['testXML']).to be_truthy
      expect(antigen_hash[:testXML]).to eq(nil)
    end
    it 'turns single tags into a key/value pair' do
      xml_string = '<testXML><levelOne><level2><something /></level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash['testXML']['levelOne']['level2'].class.name).to eq('Hash')
    end
    it 'turns multipe tags into an Array' do
      xml_string = '<testXML><levelOne><level2><something /></level2><level2><something /> \
                    </level2></levelOne></testXML>'
      antigen_importer = AntigenImporter.new
      antigen_hash = antigen_importer.xml_to_hash(xml_string)
      expect(antigen_hash['testXML']['levelOne']['level2'].class.name).to eq('Array')
    end
  end

  describe 'pulling data from the xml hash' do
    let(:antigen_importer) { AntigenImporter.new }
    let(:xml_string) { TestAntigen::ANTIGENSTRING }
    let(:xml_hash) { antigen_importer.xml_to_hash(xml_string) }

    describe '#import_antigen_xml_files' do
      it 'takes a directory of antigen xml files and imports them' do
        expect(Antigen.all.length).to eq(0)
        antigen_importer.import_antigen_xml_files('spec/support/xml')
        expect(Antigen.all.length).to eq(17)
        expect(Antigen.find_by(target_disease: 'diphtheria').series.length).to eq(1)
        expect(Antigen.find_by(target_disease: 'polio').series.length).to eq(3)
        expect(Antigen.find_by(target_disease: 'hepb').series.length).to eq(5)
        expect(Antigen.find_by(target_disease: 'pneumococcal').series.length).to eq(6)
      end
    end

    describe '#parse_and_hash' do
      it 'takes a file path string and returns the hash of xml file' do
        expect(
          antigen_importer.parse_and_hash('spec/support/xml/AntigenSupportingData- Diphtheria.xml')
        ).to eq(XMLHash::SAMPLEDIPHTHERIA)
        expect(
          antigen_importer.parse_and_hash('spec/support/xml/AntigenSupportingData- Diphtheria.xml').
            class.name
        ).to eq('Hash')
      end
    end

    describe '#parse_antigen_data_and_create_subobjects' do
      it 'takes an xml_file_hash and creates all antigen series for the antigen' do
        antigen_importer.parse_antigen_data_and_create_subobjects(xml_hash)
        antigen = Antigen.find_by(target_disease: 'polio')
        expect(antigen.series.length).to eq(3)
        expect(antigen.class.name).to eq('Antigen')
      end
      it 'saves the antigens by lowercase name' do
        antigen_importer.parse_antigen_data_and_create_subobjects(xml_hash)
        expect(Antigen.find_by(target_disease: 'polio').class.name).to eq('Antigen')
      end
    end

    describe '#create_all_antigen_series' do
      let(:antigen_object) { FactoryGirl.create(:antigen) }

      it 'takes an antigen_xml_hash and returns an array of antigen_series' do
        antigen_series = antigen_importer.create_all_antigen_series(xml_hash, antigen_object)
        expect(antigen_series.first.class.name).to eq('AntigenSeries')
      end

      it 'can take a single antigen_series attribute' do
        antigen_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGZOSTER)

        antigen_series = antigen_importer.create_all_antigen_series(antigen_hash, antigen_object)
        expect(antigen_series.first.class.name).to eq('AntigenSeries')
        expect(antigen_series.length).to eq(1)
      end

      it 'can take multiple antigen_series attributes' do
        antigen_series = antigen_importer.create_all_antigen_series(xml_hash, antigen_object)
        expect(antigen_series.first.class.name).to eq('AntigenSeries')
        expect(antigen_series.length).to eq(3)
      end

      describe 'it creates all child objects' do
        let(:antigen_series) { antigen_importer.create_all_antigen_series(xml_hash, antigen_object) }

        it 'creates all child antigen_doses' do
          expect(antigen_series.first.doses.length).to eq(4)
          expect(antigen_series.first.doses.first.class.name).to eq('AntigenSeriesDose')
        end

        it 'creates all intervals for antigen_series_doses' do
          expect(antigen_series.first.doses[1].intervals.length).to eq(1)
          expect(
            antigen_series.first.doses[1].intervals.first.class.name
          ).to eq('Interval')
        end

        it 'creates all preferable_intervals for antigen_series_doses' do
          expect(antigen_series.first.doses[1].preferable_intervals.length).to eq(1)
          expect(
            antigen_series.first.doses[1].preferable_intervals.first.class.name
          ).to eq('Interval')
          expect(
            antigen_series.first.doses[1].preferable_intervals.first.allowable
          ).to eq(false)
        end

        it 'creates all allowable_intervals for antigen_series_doses' do
          # ["antigenSupportingData"]["series"][0]["seriesDose"][1]
          antigen_series_xml_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGHEPA)
          a_series = antigen_importer.create_all_antigen_series(antigen_series_xml_hash,
                                                                antigen_object)
          expect(a_series.first.doses[1].intervals.length).to eq(2)
          expect(
            a_series.first.doses[1].allowable_intervals.first.class.name
          ).to eq('Interval')
          expect(
            a_series.first.doses[1].allowable_intervals.first.allowable
          ).to eq(true)
        end

        it 'creates all child antigen_dose_vaccines' do
          expect(antigen_series.first.doses.first.dose_vaccines.length).to eq(9)
          expect(
            antigen_series.first.doses.first.dose_vaccines.first.class.name
          ).to eq('AntigenSeriesDoseVaccine')
        end

        it 'creates no conditional_skip for none' do
          expect(antigen_series.first.doses.first.conditional_skip).to eq(nil)
        end

        it 'creates all conditional_skips' do
          expect(antigen_series.first.doses[2].conditional_skip.class.name).to eq('ConditionalSkip')
        end

        it 'creates all conditional_skip_sets' do
          expect(antigen_series.first.doses[2].conditional_skip.sets.length).to eq(1)
          expect(
            antigen_series.first.doses[2].conditional_skip.sets.first.class.name
          ).to eq('ConditionalSkipSet')
        end

        it 'creates all conditional_skip_conditions' do
          expect(antigen_series.first.doses[2].conditional_skip.sets.first.conditions.length).to eq(2)
          expect(
            antigen_series.first.doses[2].conditional_skip.sets.first.conditions.first.class.name
          ).to eq('ConditionalSkipCondition')
        end
      end
    end

    describe '#create_antigen_series_doses' do
      let(:antigen_series) { FactoryGirl.create(:antigen_series) }
      let(:series_xml_hash) { xml_hash["antigenSupportingData"]["series"][0] }

      it 'antigen_series_hash:hash, antigen_series:object => array of antigen_series_dose objects' do
        expect(antigen_series.doses).to eq([])
        antigen_importer.create_antigen_series_doses(
            series_xml_hash,
            antigen_series
          )
        antigen_series.reload
        expect(antigen_series.doses.first.class.name).to eq('AntigenSeriesDose')
      end

      it 'can process only one dose' do
        antigen_hash =
          antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGZOSTER)
        antigen_series_with_one_dose_hash = antigen_hash["antigenSupportingData"]["series"]

        expect(antigen_series.doses).to eq([])
        antigen_importer.create_antigen_series_doses(
          antigen_series_with_one_dose_hash,
          antigen_series
        )
        antigen_series.reload
        expect(antigen_series.doses.first.class.name).to eq('AntigenSeriesDose')
        expect(antigen_series.doses.length).to eq(1)
      end

      it 'can process many doses' do
        expect(antigen_series.doses).to eq([])
        antigen_importer.create_antigen_series_doses(
          series_xml_hash,
          antigen_series
        )
        antigen_series.reload
        expect(antigen_series.doses.first.class.name).to eq('AntigenSeriesDose')
        expect(antigen_series.doses.length > 1).to eq(true)
      end

      it 'sets the recurring dose to false if false' do
        expect(antigen_series.doses).to eq([])
        antigen_importer.create_antigen_series_doses(
          series_xml_hash,
          antigen_series
        )
        antigen_series.reload
        expect(antigen_series.doses.map(&:recurring_dose)).to eq([false, false, false, false])
      end

      it 'sets the recurring dose to true if true' do
        series_xml_hash['seriesDose'].first['recurringDose'] = 'Yes'
        expect(antigen_series.doses).to eq([])
        antigen_importer.create_antigen_series_doses(
          series_xml_hash,
          antigen_series
        )
        antigen_series.reload
        expect(antigen_series.doses.map(&:recurring_dose)).to eq([true, false, false, false])
      end
      describe 'with required_gender' do
        before(:all) do
          seed_antigen_xml_polio
          seed_antigen_xml_hpv
        end
        after(:all) { DatabaseCleaner.clean_with(:truncation) }

        it 'can process one gender with \'HPV Male 3 Dose\'' do
          hpv_antigen_series =
            AntigenSeries.where(name: 'HPV Male 3 Dose').first
          required_gender = hpv_antigen_series.doses.first.required_gender
          expect(required_gender).to eq(['male'])
        end
        it 'can process two genders with \'HPV Women 3 Dose\'' do
          hpv_antigen_series =
            AntigenSeries.where(name: 'HPV Female 3 Dose').first
          required_gender    = hpv_antigen_series.doses.first.required_gender
          expect(required_gender).to eq(['female', 'unknown'])
        end
        it 'can process no genders with \'Polio - All IPV - 4 Dose\'' do
          hpv_antigen_series =
            AntigenSeries.where(name: 'Polio - All IPV - 4 Dose').first
          required_gender    = hpv_antigen_series.doses.first.required_gender
          expect(required_gender).to eq([])
        end
      end
    end

    describe '#create_dose_intervals' do
      let(:antigen_series_dose) { FactoryGirl.create(:antigen_series_dose) }
      let(:antigen_series_xml_hash) do
        antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGHEPA)
      end

      let(:antigen_series_most_recent_xml_hash) do
        antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGPNEUMOCOCCAL)
      end

      it 'can process only one interval' do
        one_interval_hash =
          antigen_series_xml_hash['antigenSupportingData']['series'][1]['seriesDose'][1]
        dose_intervals = antigen_importer.create_dose_intervals(
          one_interval_hash,
          antigen_series_dose
        )
        expect(dose_intervals.first.class.name).to eq('Interval')
        expect(dose_intervals.length).to eq(1)
        expect(antigen_series_dose.intervals).to eq(dose_intervals)
      end

      it 'can process from_target_dose intervals' do
        multiple_interval_hash =
          antigen_series_xml_hash['antigenSupportingData']['series'][0]['seriesDose'][1]
        dose_intervals = antigen_importer.create_dose_intervals(
          multiple_interval_hash,
          antigen_series_dose
        )
        expect(dose_intervals.second.class.name).to eq('Interval')
        expect(dose_intervals.length).to eq(2)

        allowable_interval = dose_intervals.second
        expect(allowable_interval.allowable).to eq(true)
        expect(allowable_interval.target_dose_number).to eq(1)
      end

      it 'can process from_most_recent intervals' do
        # antigen_series_most_recent_xml_hash['antigenSupportingData']['series'][4]['seriesDose'][1]['interval'][1]['fromMostRecent']
        multiple_interval_hash =
          antigen_series_most_recent_xml_hash['antigenSupportingData']['series'][4]['seriesDose'][1]
        dose_intervals = antigen_importer.create_dose_intervals(
          multiple_interval_hash,
          antigen_series_dose
        )
        expect(dose_intervals.second.class.name).to eq('Interval')
        expect(dose_intervals.length).to eq(2)

        allowable_interval = dose_intervals.second
        expect(allowable_interval.allowable).to eq(false)
        expect(allowable_interval.recent_cvx_code).to eq(33)
        expect(allowable_interval.recent_vaccine_type).to eq('PPSV23')
      end

      context 'with multiple intervals' do
        it 'can process many intervals' do
          many_intervals_hash = antigen_series_xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][1]
          dose_intervals = antigen_importer.create_dose_intervals(many_intervals_hash,
                                                                  antigen_series_dose)
          expect(dose_intervals.first.class.name).to eq('Interval')
          expect(dose_intervals.length).to eq(2)
          expect(antigen_series_dose.intervals).to eq(dose_intervals)
        end
        it 'creates the intervals based by type (allowable or not)' do
          many_intervals_hash = antigen_series_xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][1]
          dose_intervals = antigen_importer.create_dose_intervals(
            many_intervals_hash,
            antigen_series_dose
          )
          expect(dose_intervals.first.allowable).to eq(false)
          expect(dose_intervals.last.allowable).to eq(true)
        end
      end
      it 'can process no intervals' do
        no_interval_hash = antigen_series_xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][0]
        dose_intervals = antigen_importer.create_dose_intervals(
          no_interval_hash,
          antigen_series_dose
        )
        expect(dose_intervals).to eq([])
        antigen_series_dose.reload
        expect(antigen_series_dose.intervals).to eq([])
      end
      it 'will not error but instead give nil if the xml subkey (for attribute) is not there' do
        many_intervals_hash = antigen_series_xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][1]
        dose_intervals = antigen_importer.create_dose_intervals(
          many_intervals_hash,
          antigen_series_dose
        )
        allowable_interval = dose_intervals.find {|i| i.allowable == true }
        expect(allowable_interval.allowable).to eq(true)
        expect(allowable_interval.interval_min.nil?).to eq(true)
        expect(allowable_interval.interval_absolute_min).to eq('6 months')
      end
    end

    describe '#create_antigen_series_dose_vaccines' do
      let(:antigen_series_dose) { FactoryGirl.create(:antigen_series_dose) }
      let(:antigen_dose_hash) do
        xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][2]
      end

      it 'antigen_dose_hash:hash, antigen_series_dose:object => array of antigen_series_dose_vaccine objects' do
        expect(antigen_series_dose.dose_vaccines).to eq([])
        antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_hash,
            antigen_series_dose
          )
        expect(antigen_series_dose.dose_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
      end

      it 'returns both preferable and allowable dose_vaccine objects' do
        expect(antigen_series_dose.dose_vaccines).to eq([])
        antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_hash,
            antigen_series_dose
          )
        num_total_vaccines = antigen_series_dose.preferable_vaccines.length +
                             antigen_series_dose.allowable_vaccines.length
        expect(antigen_series_dose.dose_vaccines.length).to eq(num_total_vaccines)
      end

      it 'adds dose_vaccines to the antigen_series_dose' do
        expect(antigen_series_dose.dose_vaccines).to eq([])
        antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_hash,
            antigen_series_dose
          )
        antigen_series_dose_reloaded = AntigenSeriesDose.find(antigen_series_dose.id)
        expect(antigen_series_dose.dose_vaccines.length).not_to eq([])
      end

      context 'creating preferedable vaccines' do
        it 'will create preferedable_vaccines' do
          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.preferable_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
        end
        it 'can process only one preferedable_vaccine' do
          antigen_dose_single_prefered_hash = xml_hash["antigenSupportingData"]["series"][2]["seriesDose"][0]
          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_single_prefered_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.preferable_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
          expect(antigen_series_dose.preferable_vaccines.length).to eq(1)
        end
        it 'can process multiple preferedable_vaccines' do
          antigen_dose_multiple_prefered_hash = xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][0]
          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_multiple_prefered_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.preferable_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
          expect(antigen_series_dose.preferable_vaccines.length > 1).to eq(true)
        end
      end
      context 'creating allowable vaccines' do
        it 'will create allowable_vaccines' do
          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.allowable_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
        end
        it 'can process only one allowable_vaccine' do
          antigen_dose_single_allowed_hash = xml_hash["antigenSupportingData"]["series"][2]["seriesDose"][0]
          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_single_allowed_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.allowable_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
          expect(antigen_series_dose.allowable_vaccines.length).to eq(1)
        end
        it 'can process many allowable_vaccines' do
          antigen_dose_multiple_allowed_hash = xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][0]
          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_multiple_allowed_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.allowable_vaccines.first.class.name).to eq('AntigenSeriesDoseVaccine')
          expect(antigen_series_dose.allowable_vaccines.length > 1).to eq(true)
        end
        it 'can process no allowable vaccines and return an empty array' do
          antigen_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGHEPA)
          antigen_dose_without_allowable_hash = antigen_hash["antigenSupportingData"]["series"][1]["seriesDose"][0]
          expect(antigen_dose_without_allowable_hash['allowableVaccine']).to eq(nil)

          antigen_importer.create_antigen_series_dose_vaccines(
            antigen_dose_without_allowable_hash,
            antigen_series_dose
          )
          expect(antigen_series_dose.allowable_vaccines).to eq([])
          expect(antigen_series_dose.preferable_vaccines).not_to eq([])
        end
      end
    end

    describe '#create_conditional_skips' do
      let(:antigen_dose_w_conditional_skip_hash) do
        xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][2]
      end
      let(:antigen_dose_w_out_conditional_skip_hash) do
        xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][0]
      end
      let(:series_dose) { FactoryGirl.create(:antigen_series_dose) }

      context 'with conditional_skip data' do
        it 'antigen_dose_hash:hash, antigen_dose:object => conditional_skip_object' do
          conditional_skip = antigen_importer.create_conditional_skips(
            antigen_dose_w_conditional_skip_hash,
            series_dose
          )
          expect(conditional_skip.class.name).to eq('ConditionalSkip')
        end

        it 'has an antigen_series_dose object associated' do
          conditional_skip = antigen_importer.create_conditional_skips(
            antigen_dose_w_conditional_skip_hash,
            series_dose
          )
          expect(conditional_skip.antigen_series_dose).to eq(series_dose)
        end

        it 'has set_logic assigned to it' do
          conditional_skip = antigen_importer.create_conditional_skips(
            antigen_dose_w_conditional_skip_hash,
            series_dose
          )
          expect(conditional_skip.set_logic).to eq('n/a')
        end
      end
      context 'without conditional_skip data' do
        it 'antigen_dose_hash:hash, antigen_dose:object => nil (no conditional skip arguments passed in)' do
          nil_value = antigen_importer.create_conditional_skips(
            antigen_dose_w_out_conditional_skip_hash,
            series_dose
          )
          expect(nil_value).to eq(nil)
        end
      end
    end

    describe '#create_conditional_skip_sets' do
      let(:single_conditional_skip_hash) do
        xml_hash["antigenSupportingData"]["series"][0]["seriesDose"][2]['conditionalSkip']
      end
      let(:multiple_sets_conditional_skip_hash) do
        new_xml_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGDIPHTHERIA)
        new_xml_hash["antigenSupportingData"]["series"]["seriesDose"][0]['conditionalSkip']
      end
      let(:conditional_skip) { FactoryGirl.create(:conditional_skip) }

      it 'conditional_skip_hash:hash, conditional_skip:object => array of conditional_skip_sets' do
        sets = antigen_importer.create_conditional_skip_sets(
          multiple_sets_conditional_skip_hash,
          conditional_skip
        )
        expect(sets.first.class.name).to eq('ConditionalSkipSet')
        expect(sets.first.set_id).to eq(1)
        expect(sets.last.set_id).to eq(2)
        expect(sets.length).to eq(2)
      end
      it 'can take a conditional_skip hash with a hash of one set' do
        sets = antigen_importer.create_conditional_skip_sets(
          single_conditional_skip_hash,
          conditional_skip
        )
        expect(sets.length).to eq(1)
      end
      it 'takes an conditional_skip hash with an array with many sets' do
        sets = antigen_importer.create_conditional_skip_sets(
          multiple_sets_conditional_skip_hash,
          conditional_skip
        )
        expect(sets.length).to eq(2)
      end
    end

    describe '#create_conditional_skip_conditions' do
      let(:single_condition_set_hash) do
        new_xml_hash = antigen_importer.xml_to_hash(TestAntigen::ANTIGENSTRINGDIPHTHERIA)
        new_xml_hash["antigenSupportingData"]["series"]["seriesDose"][0]['conditionalSkip']["set"][0]
      end
      let(:multiple_condition_set_hash) do
        xml_hash["antigenSupportingData"]["series"][2]["seriesDose"][2]['conditionalSkip']["set"]
      end
      let(:conditional_skip_set) { FactoryGirl.create(:conditional_skip_set) }

      it 'conditional_skip_set_hash:hash, conditional_skip_set:object => array of conditions' do
        conditions = antigen_importer.create_conditional_skip_conditions(
          multiple_condition_set_hash,
          conditional_skip_set
        )
        expect(conditions.first.class.name).to eq('ConditionalSkipCondition')
        expect(conditions.first.condition_id).to eq(1)
        expect(conditions.last.condition_id).to eq(2)
        expect(conditions.length).to eq(2)
      end
      it 'can take a conditional_skip_set hash with a hash of one condition' do
        conditions = antigen_importer.create_conditional_skip_conditions(
          single_condition_set_hash,
          conditional_skip_set
        )
        expect(conditions.length).to eq(1)
      end
      it 'takes an conditional_skip_set hash with an array with many conditions' do
        conditions = antigen_importer.create_conditional_skip_conditions(
          multiple_condition_set_hash,
          conditional_skip_set
        )
        expect(conditions.length).to eq(2)
      end
    end
    describe 'cvx_to_antigen methods' do
      let(:valid_cvx_to_antigen_map) do
        <<-eos
          <cvxMap>
          <cvx>01</cvx>
          <shortDescription>DTP</shortDescription>
          <association>
          <antigen>Diphtheria</antigen>
          <associationBeginAge />
          <associationEndAge />
          </association>
          <association>
          <antigen>Tetanus</antigen>
          <associationBeginAge />
          <associationEndAge />
          </association>
          <association>
          <antigen>Pertussis</antigen>
          <associationBeginAge />
          <associationEndAge />
          </association>
          </cvxMap>
        eos
      end
      describe '#pull_cvx_to_antigen_arguments' do
        it 'pulls the information into an argument hash' do
          cvx_hash = antigen_importer.xml_to_hash(valid_cvx_to_antigen_map)
          cvx_hash = cvx_hash['cvxMap']
          argument_hash =
            antigen_importer.pull_cvx_to_antigen_arguments(cvx_hash)

          expected_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria', 'tetanus', 'pertussis']
          }
          expect(argument_hash).to eq(expected_argument_hash)
        end
        it 'can handle a singular antigen map' do
          cvx_to_antigen_map = <<-eos
            <cvxMap>
            <cvx>01</cvx>
            <shortDescription>DTP</shortDescription>
            <association>
            <antigen>Diphtheria</antigen>
            <associationBeginAge />
            <associationEndAge />
            </association>
            </cvxMap>
          eos
          cvx_hash      = antigen_importer.xml_to_hash(cvx_to_antigen_map)
          cvx_hash      = cvx_hash['cvxMap']
          argument_hash =
            antigen_importer.pull_cvx_to_antigen_arguments(cvx_hash)

          expected_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria']
          }
          expect(argument_hash).to eq(expected_argument_hash)
        end
      end
      describe '#create_or_update_cvx_to_antigen_association' do
        it 'creates a new VaccineInfo object if none exists' do
          expect(VaccineInfo.find_by(cvx_code: 01)).to eq(nil)
          cvx_to_antigen_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria', 'tetanus', 'pertussis']
          }
          antigen_importer.create_or_update_cvx_to_antigen_association(
            cvx_to_antigen_argument_hash
          )
          expect(VaccineInfo.find_by(cvx_code: 01)).not_to eq(nil)
        end
        it 'creates new Antigen objects if none exist' do
          expect(Antigen.find_by(target_disease: 'diphtheria')).to eq(nil)
          expect(Antigen.find_by(target_disease: 'tetanus')).to eq(nil)
          expect(Antigen.find_by(target_disease: 'pertussis')).to eq(nil)
          cvx_to_antigen_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria', 'tetanus', 'pertussis']
          }
          antigen_importer.create_or_update_cvx_to_antigen_association(
            cvx_to_antigen_argument_hash
          )
          expect(Antigen.find_by(target_disease: 'diphtheria')).not_to eq(nil)
          expect(Antigen.find_by(target_disease: 'tetanus')).not_to eq(nil)
          expect(Antigen.find_by(target_disease: 'pertussis')).not_to eq(nil)
        end
        it 'deletes a VaccineInfo object and recreates one if one exists' do
          cvx_to_antigen_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria']
          }
          antigen_importer.create_or_update_cvx_to_antigen_association(
            cvx_to_antigen_argument_hash
          )
          vaccine_info_object = VaccineInfo.find_by(cvx_code: 01)
          expect(vaccine_info_object.antigens.length).to eq(1)

          cvx_to_antigen_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria', 'tetanus', 'pertussis']
          }
          antigen_importer.create_or_update_cvx_to_antigen_association(
            cvx_to_antigen_argument_hash
          )
          vaccine_info_object2 = VaccineInfo.find_by(cvx_code: 01)
          expect(vaccine_info_object.id).not_to eq(vaccine_info_object2.id)
          expect(vaccine_info_object2.antigens.length).to eq(3)
        end
        it 'updates the Antigen objects if they exist' do
          cvx_to_antigen_argument_hash = {
            cvx_code: 01,
            short_description: 'dtp',
            antigens: ['diphtheria', 'tetanus', 'pertussis']
          }
          antigen_importer.create_or_update_cvx_to_antigen_association(
            cvx_to_antigen_argument_hash
          )
          diphtheria = Antigen.find_by(target_disease: 'diphtheria')
          tetanus    = Antigen.find_by(target_disease: 'tetanus')
          pertussis  = Antigen.find_by(target_disease: 'pertussis')

          expect(diphtheria.vaccine_infos.length).to eq(1)
          expect(tetanus.vaccine_infos.length).to eq(1)
          expect(pertussis.vaccine_infos.length).to eq(1)

          cvx_to_antigen_argument_hash2 = {
            cvx_code: 9,
            short_description: 'Td (adult), adsorbed',
            antigens: ['diphtheria', 'tetanus']
          }
          antigen_importer.create_or_update_cvx_to_antigen_association(
            cvx_to_antigen_argument_hash2
          )
          expect(VaccineInfo.all.length).to eq(2)
          [diphtheria, tetanus, pertussis].each { |antigen| antigen.reload }
          expect(diphtheria.vaccine_infos.length).to eq(2)
          expect(tetanus.vaccine_infos.length).to eq(2)
          expect(pertussis.vaccine_infos.length).to eq(1)
        end
      end
      describe '#create_all_cvx_to_antigen_mappings' do
        let(:valid_cvx_to_antigen_xml_hash) do
          antigen_importer.xml_to_hash(TestAntigen::CVXTOANTIGENMAP)
        end
        it 'creates all mappings in the database' do
          all_antigen_hash = {
            1 => ['Diphtheria', 'Tetanus', 'Pertussis'],
            2 => ['Polio'],
            3 => ['Measles', 'Mumps', 'Rubella'],
            4 => ['Measles', 'Rubella'],
            5 => ['Measles'],
            6 => ['rubella'],
            7 => ['mumps'],
            8 => ['Hep B'],
            9 => ['Tetanus', 'Diphtheria'],
            10 => ['polio'],
            15 => ['influenza'],
            16 => ['influenza'],
            17 => ['Hib'],
            20 => ['Diphtheria', 'Tetanus', 'Pertussis'],
            21 => ['varicella'],
            22 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Hib'],
            28 => ['Diphtheria', 'Tetanus'],
            32 => ['MCV'],
            33 => ['Pneumococcal'],
            35 => ['Tetanus'],
            38 => ['Rubella', 'Mumps'],
            42 => ['Hep B'],
            43 => ['Hep B'],
            44 => ['Hep B'],
            45 => ['Hep B'],
            46 => ['Hib'],
            47 => ['Hib'],
            48 => ['Hib'],
            49 => ['Hib'],
            50 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Hib'],
            51 => ['Hib', 'Hep B'],
            52 => ['Hep A'],
            62 => ['HPV'],
            74 => ['Rotavirus'],
            83 => ['Hep A'],
            84 => ['Hep A'],
            85 => ['Hep A'],
            88 => ['Influenza'],
            89 => ['Polio'],
            94 => ['Measles', 'Mumps', 'Rubella', 'Varicella'],
            100 => ['Pneumococcal'],
            102 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Hib', 'Hep B'],
            104 => ['Hep A', 'Hep B'],
            106 => ['Diphtheria', 'Tetanus', 'Pertussis'],
            107 => ['Diphtheria', 'Tetanus', 'Pertussis'],
            108 => ['MCV'],
            109 => ['Pneumococcal'],
            110 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Hep B', 'Polio'],
            111 => ['Influenza'],
            113 => ['Tetanus', 'Diphtheria'],
            114 => ['MCV'],
            115 => ['Tetanus', 'Diphtheria', 'Pertussis'],
            116 => ['Rotavirus'],
            118 => ['HPV'],
            119 => ['Rotavirus'],
            120 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Hib', 'Polio'],
            121 => ['Varicella', 'Zoster'],
            122 => ['Rotavirus'],
            130 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Polio'],
            132 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Polio', 'Hib', 'Hep B'],
            133 => ['Pneumococcal'],
            135 => ['Influenza'],
            136 => ['MCV'],
            137 => ['HPV'],
            138 => ['Tetanus', 'Diphtheria'],
            139 => ['Tetanus', 'Diphtheria'],
            140 => ['Influenza'],
            141 => ['Influenza'],
            144 => ['Influenza'],
            146 => ['Diphtheria', 'Tetanus', 'Pertussis', 'Hib', 'Hep B'],
            147 => ['MCV'],
            148 => ['MCV', 'Hib'],
            149 => ['Influenza'],
            150 => ['Influenza'],
            151 => ['Influenza'],
            152 => ['Pneumococcal'],
            153 => ['Influenza'],
            155 => ['Influenza'],
            158 => ['Influenza'],
            161 => ['Influenza'],
            165 => ['HPV'],
            166 => ['Influenza']
          }
          antigen_importer.create_all_cvx_to_antigen_mappings(
            valid_cvx_to_antigen_xml_hash
          )
          all_antigen_hash.each do |key, antigens|
            vaccine_info = VaccineInfo.find_by(cvx_code: key.to_i)
            antigens_names = antigens.map do |antigen|
              if antigen == 'Hep B' || antigen == 'hep b'
                'hepb'
              else
                antigen.downcase
              end
            end
            vaccine_info_antigens = vaccine_info.antigens.map(&:target_disease)
            expect(antigens_names).to match_array(vaccine_info_antigens)
          end
        end
      end
    end
  end
end
