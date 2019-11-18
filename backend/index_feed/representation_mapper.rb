require_relative 'abstract_mapper'

class RepresentationMapper < AbstractMapper

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['id'] = "%s:%s" % [json['jsonmodel_type'], obj.id]

    whitelisted['qsa_id'] = json['qsa_id']
    whitelisted['qsa_id_prefixed'] = json['qsa_id_prefixed']

    whitelisted['jsonmodel_type'] = json['jsonmodel_type']

    whitelisted['display_string'] = json['display_string']
    whitelisted['title'] = json['title']
    whitelisted['description'] = json['description']
    whitelisted['agency_assigned_id'] = json['agency_assigned_id']
    whitelisted['external_ids'] = parse_external_ids(json['external_ids'])

    whitelisted['intended_use'] = json['intended_use'] ? I18n.t("enumerations.runcorn_intended_use.#{json['intended_use']}", default: json['intended_use']) : json['intended_use']
    whitelisted['preferred_citation'] = json['preferred_citation']
    whitelisted['remarks'] = json['remarks']
    whitelisted['processing_handling_notes'] = json['processing_handling_notes']

    whitelisted['rap_applied'] = parse_rap(json['rap_applied'])
    whitelisted['rap_access_status'] = parse_rap(json['rap_access_status'])
    whitelisted['rap_expiration'] = json['rap_expiration']

    whitelisted['controlling_record'] = json['controlling_record']
    whitelisted['responsible_agency'] = json['responsible_agency']

    whitelisted['previous_system_ids'] = parse_previous_system_ids(json)

    if json['jsonmodel_type'] == 'physical_representation'
      whitelisted['format'] = json['format']
      whitelisted['availability'] = json['calculated_availability']

    elsif json['jsonmodel_type'] == 'digital_representation'
      whitelisted['file_size'] = json['file_size']
      whitelisted['file_type'] = json['file_type']

      if json['rap_access_status'] == 'Open Access'
        whitelisted['representation_file'] = json['representation_file']
      end
    end

    whitelisted
  end

  def available?(json)
    if json['jsonmodel_type'] == 'physical_representation'
      if json['calculated_availability'] === 'unavailable_due_to_deaccession'
        return false
      end
    end

    true
  end

  def published?(jsonmodel)
    jsonmodel['publish'] && !jsonmodel['has_unpublished_ancestor'] && available?(jsonmodel)
  end

  def map_record(obj, json, solr_doc)
    solr_doc['parent_solr_doc_uri'] = (json['controlling_record'] || {}).fetch('ref', nil)

    solr_doc['id'] = "%s:%s" % [json['jsonmodel_type'], obj.id]
    solr_doc['primary_type'] = json['jsonmodel_type']
    solr_doc['json'] = ASUtils.to_json(parse_whitelisted_json(obj, json))

    solr_doc
  end

  def parse_previous_system_ids(json)
    super + json['previous_system_identifiers'].to_s.split("\n").map{|s| s.strip}.reject{|s| s.empty?}
  end
end
