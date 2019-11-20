module ReadingroomRequestItem

  extend JSONModel

  def self.included(base)
    base.extend(ClassMethods)
  end


  def update_from_json(json, opts = {}, apply_nested_records = true)
    obj = super
    self.reindex_reading_room_requests!
    obj
  end


  def reindex_reading_room_requests!
    self.class.reindex_reading_room_requests!([self.id])
  end


  module ClassMethods
    def create_from_json(json, extra_values = {})
      obj = super
      obj.reindex_reading_room_requests!
      obj
    end


    def reindex_reading_room_requests!(physical_representation_ids)
      PublicDB.open do |pdb|
        pdb[:reading_room_request]
          .filter(:item_id => physical_representation_ids.map{|id| "physical_representation:#{id}"})
          .update(:system_mtime => Time.now)
      end
    end


    def handle_delete(ids_to_delete)
      super
      self.reindex_reading_room_requests!(item_ids)
    end
  end
end
