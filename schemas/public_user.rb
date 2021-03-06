{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {
      "id" => {"type" => "integer"},
      "email" => {"type" => "string"},
      "first_name" => {"type" => "string"},
      "last_name" => {"type" => "string"},
      "verified" => {"type" => "boolean"},
    }
  }
}
