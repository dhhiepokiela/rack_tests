require_relative 'environment.rb'

namespace :system do
  task console: :environment do |t| 
    binding.pry
  end
end