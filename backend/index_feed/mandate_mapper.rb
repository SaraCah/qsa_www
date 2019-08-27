require_relative 'abstract_mapper'

class MandateMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

end