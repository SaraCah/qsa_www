require_relative 'abstract_mapper'

class AgencyMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    super
  end

  def published?(jsonmodel)
    # super && jsonmodel['is_linked_to_published_record']
    # FIXME I think we want all agencies to be available
    # based on their publish flag??
    super
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['display_string'] = json.title
    whitelisted['abstract'] = json.agency_note
    whitelisted['display_name'] = parse_names([json.display_name]).first
    whitelisted['names'] = parse_names(json.names)
    whitelisted['notes'] = parse_notes(json.notes)
    whitelisted['dates'] = parse_dates(json.dates_of_existence)
    whitelisted['external_documents'] = parse_external_documents(json.external_documents)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships, ['series_system_agent_agent_succession_relationship', 'series_system_agent_agent_containment_relationship', 'series_system_agent_agent_ownership_relationship', 'series_system_agent_agent_association_relationship'])
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships, ['series_system_agent_function_administers_relationship'])
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships, ['series_system_agent_mandate_administers_relationship'])

    whitelisted
  end

  def parse_description(jsonmodel)
    "[PLACEHOLDER FOR AGENCY DESCRIPTION]"
  end

  def parse_external_resources(resources)
    resources.select{|ref| ref['publish']}
  end

  def parse_notes(notes)
    # FIXME need to confirm what notes are supported in public?
    # Assume published for now
    #
    # super.select{|note| note['jsonmodel_type'] == 'note_bioghist' }
    super
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