ArchivesSpace::Application.routes.draw do
  resources :reading_room_requests
  match 'reading_room_requests/picking_slip/download' => 'reading_room_requests#picking_slip', :via => [:get]
  match 'reading_room_requests/:id/set_status' => 'reading_room_requests#set_status', :via => [:post]
  match 'reading_room_requests/bulk_set_status' => 'reading_room_requests#bulk_set_status', :via => [:post]

  match 'digital_copy_prices' => 'digital_copy_pricing#index', :via => [:get]
  match 'digital_copy_prices' => 'digital_copy_pricing#create', :via => [:post]
  match 'digital_copy_prices/delete' => 'digital_copy_pricing#delete', :via => [:post]
end
