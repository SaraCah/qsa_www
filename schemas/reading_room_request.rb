{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "uri" => "/reading_room_requests",
    "properties" => {
      "uri" => {"type" => "string"},

      "user_id" => {"type" => "string"},
      "agency_request_id" => {"type" => "string"},
      "item_id" => {"type" => "string"},
      "item_uri" => {"type" => "string"},
      "status" => {"type" => "string"},
      "date_required" => {"type" => "string"},

      "requested_item" => {
        "readonly" => "true",
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {
            "type" => "JSONModel(:physical_representation) uri",
          },
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        }
      },

      "created_by" => {"type" => "string"},
      "modified_by" => {"type" => "string"},
      "create_time" => {"type" => "string"},
      "modified_time" => {"type" => "string"},
    }
  }
}
