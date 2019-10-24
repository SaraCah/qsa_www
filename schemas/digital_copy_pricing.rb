{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "uri" => "/digital_copy_prices",
    "properties" => {
      "uri" => {"type" => "string"},

      "item" => {
        "type" => "object",
        "subtype" => "ref",
        "properties" => {
          "ref" => {
            "type" => [
              {"type" => "JSONModel(:resource) uri"},
              {"type" => "JSONModel(:archival_object) uri"},
            ],
          },
          "_resolved" => {
            "type" => "object",
            "readonly" => "true"
          },

          # "qsa_id_prefixed" => {
          #   "type" => "string",
          #   "readonly" => "true"
          # },
          #
          # "display_string" => {
          #   "type" => "string",
          #   "readonly" => "true"
          # }
        }
      },

      "price_cents" => { "type" => "string" },

      "created_by" => {"type" => "string"},
      "modified_by" => {"type" => "string"},
      "create_time" => {"type" => "integer"},
      "modified_time" => {"type" => "integer"},
    }
  }
}
