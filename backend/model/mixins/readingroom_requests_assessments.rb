module ReadingroomRequests

  extend JSONModel

  def self.included(base)
    base.extend(ClassMethods)
  end

  def update_from_json(json, opts = {}, apply_nested_records = true)
    obj = super
    self.class.reindex_reading_room_requests_for_assessments!([obj.id])
    obj
  end

  module ClassMethods
    def create_from_json(json, extra_values = {})
      obj = super
      self.reindex_reading_room_requests_for_assessments!([obj.id])
      obj
    end


    def physical_representation_ids_for(assessment_ids)
      DB.open do |db|
        db[:assessment_rlshp].filter(:assessment_id => assessment_ids)
                             .select(:physical_representation_id)
                             .map{|pr| pr[:physical_representation_id]}
      end
    end


    def reindex_reading_room_requests_for_assessments!(assessment_ids)
      self.reindex_reading_room_requests_for_items!(physical_representation_ids_for(assessment_ids))
    end


    def reindex_reading_room_requests_for_items!(physical_representation_ids)
      PublicDB.open do |pdb|
        pdb[:reading_room_request]
          .filter(:item_id => physical_representation_ids.map{|id| "physical_representation:#{id}"})
          .update(:system_mtime => Time.now)
      end
    end


    def handle_delete(ids_to_delete)
      item_ids = self.physical_representation_ids_for(ids_to_delete)
      super
      self.reindex_reading_room_requests_for_items!(item_ids)
    end
  end
end
