ArchivesSpace::Application.routes.draw do
  resources :reading_room_requests
  match 'reading_room_requests/:id/picking_slip' => 'reading_room_requests#picking_slip', :via => [:get]
  match 'reading_room_requests/:id/set_status' => 'reading_room_requests#set_status', :via => [:post]
  match 'reading_room_requests/bulk_set_status' => 'reading_room_requests#bulk_set_status', :via => [:post]
end
