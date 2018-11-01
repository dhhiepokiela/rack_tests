require_relative 'environment.rb'

namespace :service do
  task all: :environment do |t|
    starting(t)
    pass(t)
  end
  
  task phone_number: :environment do |t|
    starting(t)
    change_to_dev_server!
    resp = get('')

    %w[084 8484 08484 +8484 0124 84124 +84124].each do |phone_prefix|
      new_phone = Backend::App::MiscServices::PhoneNumberService.phone_number_conversion("#{phone_prefix}   5 28 6 828")
      resp.include?(%w[0845286828 84845286828 +84845286828 084845286828], new_phone)
    end

    pass(t)
  end
end
