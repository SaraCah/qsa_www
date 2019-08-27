require_relative 'abstract_mapper'

class ItemMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

  def published?(jsonmodel)
    return false if jsonmodel['has_unpublished_ancestor']

    super
  end
end