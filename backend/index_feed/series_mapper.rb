require_relative 'abstract_mapper'

class SeriesMapper < AbstractMapper

  def initialize(sequel_records, jsonmodels)
    super

    @linked_agents_publish_map = build_linked_agents_publish_map
    @linked_mandates_publish_map = build_linked_mandates_publish_map
    @linked_functions_publish_map = build_linked_functions_publish_map
    @descendant_counts = build_descendant_counts(sequel_records)
  end

  def build_descendant_counts(sequel_records)
    result = {}

    DB.open do |db|
      db[:archival_object]
        .filter(:root_record_id => sequel_records.map(&:id))
        .group_and_count(:root_record_id)
        .each do |row|
        result[row[:root_record_id]] = row[:count]
      end
    end

    result
  end

  def published?(jsonmodel)
    super && agency_published?(jsonmodel['responsible_agency'])
  end

  def agency_published?(agency_ref)
    if agency_ref && agency_ref['ref']
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(agency_ref['ref'])
      return @linked_agents_publish_map.fetch(agency_id)
    end

    return false
  end

  def map_record(obj, json, solr_doc)
    super

    json.creating_agency.each do |creating_agency|
      if agency_published?(creating_agency)
        agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(creating_agency.fetch('ref'))
        solr_doc['creating_agency_id'] ||= []
        solr_doc['creating_agency_id'] << "agent_corporate_entity:#{agency_id}"
      end
    end

    if agency_published?(json.responsible_agency)
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(json.responsible_agency.fetch('ref'))
      solr_doc['responsible_agency_id'] = "agent_corporate_entity:#{agency_id}"
    end

    solr_doc['mandate_id'] = parse_series_system_rlshps(json.series_system_mandate_relationships, 'series_system_mandate_series_documentation_relationship').map {|rlshp|
      mandate_id = JSONModel::JSONModel(:mandate).id_for(rlshp.fetch('ref'))
      next unless @linked_mandates_publish_map.fetch(mandate_id)

      "mandate:#{mandate_id}"
    }.compact

    solr_doc['function_id'] = parse_series_system_rlshps(json.series_system_function_relationships, 'series_system_function_series_documentation_relationship').map {|rlshp|
      function_id = JSONModel::JSONModel(:function).id_for(rlshp.fetch('ref'))
      next unless @linked_functions_publish_map.fetch(function_id)

      "function:#{function_id}"
    }.compact

    solr_doc
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['descendant_count'] = @descendant_counts.fetch(obj.id, 0)

    whitelisted['display_string'] = json.title
    whitelisted['title'] = json.title
    whitelisted['description'] = json.description
    whitelisted['abstract'] = json.abstract
    whitelisted['sensitivity_label'] = I18n.t("enumerations.runcorn_sensitivity_label.#{json.sensitivity_label}", default: json.sensitivity_label)
    whitelisted['copyright_status'] = I18n.t("enumerations.runcorn_copyright_status.#{json.copyright_status}", default: json.copyright_status)
    whitelisted['information_sources'] = json.information_sources
    whitelisted['repository_processing_note'] = split_new_lines_into_array(json.repository_processing_note)
    whitelisted['dates'] = parse_dates(json.dates)
    whitelisted['notes'] = parse_notes(json.notes)
    whitelisted['external_documents'] = parse_external_documents(json.external_documents)
    whitelisted['series_relationships'] = parse_series_system_rlshps(json.series_system_series_relationships)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(parse_agent_rlshps(json.series_system_agent_relationships))
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['rap_attached'] = parse_rap(json.rap_attached)
    whitelisted['responsible_agency'] = agency_published?(json.responsible_agency) ? json.responsible_agency : nil
    whitelisted['creating_agency'] = json.creating_agency.select{|agency| agency_published?(agency)}

    whitelisted
  end

  def parse_description(jsonmodel)
    [jsonmodel['abstract'], jsonmodel['description']].compact.join('\n\n')
  end

  def parse_previous_system_ids(json)
    super + generate_id_components(json.repository_processing_note)
  end

  def build_linked_agents_publish_map
    result = {}
    agency_ids = []
    @jsonmodels.each do |json|
      agency_ids << JSONModel::JSONModel(:agent_corporate_entity).id_for(json['responsible_agency']['ref']) if json['responsible_agency']
      Array(json['creating_agency']).each do |creating_agency|
        agency_ids << JSONModel::JSONModel(:agent_corporate_entity).id_for(creating_agency['ref'])
      end
    end

    DB.open do |db|
      db[:agent_corporate_entity]
        .filter(:id => agency_ids)
        .select(:id, :publish)
        .each do |row|
        result[row[:id]] = row[:publish] == 1
      end
    end

    result
  end

  def build_linked_mandates_publish_map
    result = {}
    mandate_ids = []

    @jsonmodels.each do |json|
      json.series_system_mandate_relationships.each do |rlshp|
        mandate_ids << JSONModel::JSONModel(:mandate).id_for(rlshp.fetch('ref'))
      end
    end

    DB.open do |db|
      db[:mandate]
        .filter(:id => mandate_ids)
        .select(:id, :publish)
        .each do |row|
        result[row[:id]] = row[:publish] == 1
      end
    end

    result
  end

  def build_linked_functions_publish_map
    result = {}
    function_ids = []

    @jsonmodels.each do |json|
      json.series_system_function_relationships.each do |rlshp|
        function_ids << JSONModel::JSONModel(:function).id_for(rlshp.fetch('ref'))
      end
    end

    DB.open do |db|
      db[:function]
        .filter(:id => function_ids)
        .select(:id, :publish)
        .each do |row|
        result[row[:id]] = row[:publish] == 1
      end
    end

    result
  end

end
