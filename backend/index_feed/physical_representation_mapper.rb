require_relative 'representation_mapper'

class PhysicalRepresentationMapper < RepresentationMapper

  def map_record(obj, json, solr_doc)
    super
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['format'] = json.format

    whitelisted
  end

end