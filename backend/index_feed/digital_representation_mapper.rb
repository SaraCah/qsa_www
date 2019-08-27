require_relative 'representation_mapper'

class DigitalRepresentationMapper < RepresentationMapper

  def map_record(obj, json, solr_doc)
    super
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['file_size'] = json.file_size
    whitelisted['file_type'] = json.file_type

    whitelisted
  end


end