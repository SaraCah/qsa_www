require_relative 'abstract_mapper'

class SubjectMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

  def published?(jsonmodel)
    jsonmodel['is_linked_to_published_record']
  end

end