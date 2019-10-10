ArchivesSpace::Application.routes.draw do
  resources :reading_room_requests
  match 'reading_room_requests/:id/picking_slip' => 'reading_room_requests#picking_slip', :via => [:get]
end
