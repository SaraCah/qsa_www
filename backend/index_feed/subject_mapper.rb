require_relative 'abstract_mapper'

class SubjectMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    # FIXME Subject things
    solr_doc['qsa_id'] = obj.id
    solr_doc['qsa_id_prefixed'] = "SUBJ#{obj.id}"
    solr_doc
  end

  def published?(jsonmodel)
    jsonmodel['is_linked_to_published_record']
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['id'] = obj.id
    whitelisted['uri'] = json.uri
    whitelisted['display_string'] = json.title
    whitelisted['source'] = json.source
    whitelisted['scope_note'] = json.scope_note
    whitelisted['terms'] = parse_terms(json.terms)

    whitelisted
  end

  def parse_terms(terms)
    terms.map do |term|
      {
        'term' => term['term'],
        'term_type' => term['term_type'],
      }
    end
  end


end