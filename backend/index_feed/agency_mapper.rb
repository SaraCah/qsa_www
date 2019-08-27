require_relative 'abstract_mapper'

class AgencyMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

end