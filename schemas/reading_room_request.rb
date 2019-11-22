{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "uri" => "/reading_room_requests",
    "properties" => {
      "uri" => {"type" => "string"},

      "title" => {"type" => "string", "readonly" => "true"},

      "user_id" => {"type" => "integer"},
      "agency_request_id" => {"type" => "integer"},
      "item_id" => {"type" => "string"},
      "item_uri" => {"type" => "string"},
      "status" => {"type" => "string"},
      "date_required" => {"type" => "integer"},

      "requested_item" => {
        "readonly" => "true",
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {
            "type" => [
              {"type" => "JSONModel(:digital_representation) uri"},
              {"type" => "JSONModel(:physical_representation) uri"},
            ]
          },
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          }
        }
      },

      "requesting_user" => {
        "type" => "JSONModel(:public_user) object"
      },

      "created_by" => {"type" => "string"},
      "modified_by" => {"type" => "string"},
      "create_time" => {"type" => "integer"},
      "modified_time" => {"type" => "integer"},
    }
  }
}
