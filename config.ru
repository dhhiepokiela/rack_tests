require 'sidekiq'

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/2', :size => 1, :password => 'okiela123' }
end

require 'sidekiq/web'
run Sidekiq::Web
