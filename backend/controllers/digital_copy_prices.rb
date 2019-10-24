class ArchivesSpaceService < Sinatra::Base

  # FIXME Need permissions on these too
  Endpoint.get('/digital_copy_prices')
    .description("List digital copy prices")
    .permissions([])
    .returns([200, "[(:digital_copy_pricing)]"]) \
    do
    handle_unlimited_listing(DigitalCopyPricing, :active => 1, :type => 'record')
  end

  Endpoint.post('/digital_copy_prices')
    .description("Create a digital copy pricing")
    .params(["digital_copy_pricing", JSONModel(:digital_copy_pricing), "The record to create", :body => true])
    .permissions([])
    .returns([200, :created]) \
    do
    DigitalCopyPricing.create_or_update(params[:digital_copy_pricing])

    [200]
  end

  Endpoint.post('/digital_copy_prices/delete')
    .description("Delete a digital copy pricing")
    .params(["uri", String, "URI of pricing to delete"])
    .permissions([])
    .returns([200, :deleted]) \
    do
    DigitalCopyPricing.make_inactive(params[:uri])

    [200]
  end

end