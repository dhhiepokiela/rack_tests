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

    %w[8484 08484 +8484 0124 84124 +84124].each do |phone_prefix|
      new_phone = Backend::App::MiscServices::PhoneNumberService.phone_number_conversion("#{phone_prefix}   5 28 6 828")
      resp.include?(%w[0845286828 84845286828 +84845286828 084845286828], new_phone)
    end

    %w[8434 08434 +8434 0164 84164 +84164].each do |phone_prefix|
      new_phone = Backend::App::MiscServices::PhoneNumberService.phone_number_conversion("#{phone_prefix}6320010")
      resp.include?(%w[0346320010 84346320010 +84346320010 084346320010], new_phone)
    end

    list = YAML.load(File.read('./cache_file/non_convertible_phone_list.yaml'))['non_convertible_phone_list']
    non_convertible_phone_list = [list['users'], list['logistic_users']].flatten
    details_msg('INFO', "Non convertible phone list has #{non_convertible_phone_list.count} items")
    non_convertible_phone_list.each do |phone|
      new_phone = Backend::App::MiscServices::PhoneNumberService.phone_number_conversion(phone)
      resp.eq?(new_phone, phone)
    end

    pass(t)
  end
end
