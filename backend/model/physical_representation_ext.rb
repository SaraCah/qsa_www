unless ASUtils.migration_mode?
  PhysicalRepresentation.include(ReadingroomRequestItem)
end
