require_relative 'abstract_mapper'

class MandateMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    super
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['display_string'] = json.display_string
    whitelisted['title'] = json.title
    whitelisted['mandate_type'] = json.mandate_type
    whitelisted['note'] = json.note
    whitelisted['date'] = parse_dates([json.date].compact).first

    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships)
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)

    whitelisted
  end

  def parse_description(jsonmodel)
    jsonmodel['note']
  end

end