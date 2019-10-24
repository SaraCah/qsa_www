class DigitalCopyPricingController < ApplicationController

  # TODO: review access controls for these endpoints
  set_access_control  "view_repository" => [:index, :create, :delete]

  def index
    @prices = JSONModel(:digital_copy_pricing).all
  end

  def create
    pricing = JSONModel(:digital_copy_pricing).from_hash({
      "item" => {
        "ref" => params[:uri],
      },
      "price_cents" => params[:price],
    })

    JSONModel::HTTP.post_json(URI("#{JSONModel::HTTP.backend_url}/digital_copy_prices"), pricing.to_json)

    render :json => {:status => 'success'}
  end

  def delete
    JSONModel::HTTP.post_form("/digital_copy_prices/delete", :uri => params[:uri])
    render :json => {:status => 'success'}
  end
end