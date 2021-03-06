require_relative 'abstract_mapper'

class AgencyMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    super
  end

  def published?(jsonmodel)
    super
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['display_string'] = parse_title(json)
    whitelisted['agency_note'] = json.agency_note
    whitelisted['display_name'] = parse_names([json.display_name]).first
    whitelisted['alternative_names'] = parse_alternative_names(json)
    whitelisted['notes'] = parse_notes(json.notes)
    whitelisted['dates'] = parse_dates(json.dates_of_existence)
    whitelisted['external_documents'] = parse_external_documents(json.external_documents)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships)
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)
    whitelisted['agency_category'] = json.agency_category
    whitelisted['agency_category_label'] = I18n.t("enumerations.agency_category.#{json.agency_category}", default: nil)

    whitelisted
  end

  def parse_title(jsonmodel)
    parse_names([jsonmodel.display_name]).first.fetch('primary_name')
  end

  def parse_description(jsonmodel)
    jsonmodel.agency_note
  end

  def parse_alternative_names(jsonmodel)
    alt_names = []

    jsonmodel.names.each do |name|
      unless name['is_display_name']
        alt_names << name['primary_name']
      end
      alt_names << name['subordinate_name_1']
      alt_names << name['subordinate_name_2']
    end

    alt_names.compact.uniq.sort
  end

  def parse_external_resources(resources)
    resources.select{|ref| ref['publish']}
  end

  def parse_notes(notes)
    supported_note_types = %w(description information_sources preferred_citation remarks legislation_establish legislation_administered legislation_abolish)

    super.select{|note| supported_note_types.include?(note['type'])}
  end

  def parse_names(names)
    names.map do |name|
      {
        'primary_name' => name['primary_name'],
        'acronym' => name['subordinate_name_1'],
        'alternative_name' => name['subordinate_name_2'],
      }
    end
  end
end