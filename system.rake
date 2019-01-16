require_relative 'environment.rb'


namespace :system do
  task console: :environment do |t|
    binding.pry
    params = {
      package_weight: '2000',
      size: '10.6x5.1x30',
      shop_dropoff_id: '27993016',
      city_id: 50,
      district_id: 563
    }

    resp = get('external_clients/delivery/price_check', params, api_token)
    resp.status_200?
  end

  task include_sunday: :environment do |t|
    (0..20).to_a.each do |i|
      start_date = 5.days_ago
      end_date = i.days_from_now
      result = start_date.range_include_sunday?(end_date)
      details_msg('INFO', "From #{start_date.strftime('%c')} #{end_date.strftime('%c')}#{result ? '' : ' not'} include Sunday", color: result ? :green : :red)
    end
  end

  task debug: :environment do |t|
    10000.times { |i| puts "##{i}: #{Backend::App::Users.by_id(ENV['ID'], true).status}"; sleep(1)}
  end

  task benchmark: :environment do |t|
    starting(t)
    dashboard_logistic_login!
    ENV['TIMES'].to_i.times do
      print_memory_usage do
        print_time_spent do
          resp = get('logistics/orders/28033677/get_okiela_drop_off_address', {}, api_token)
          resp.status_200?
        end
      end
    end
    pass(t)
  end

  task log_nginx_dev1: :environment do |t|
    starting(t)
    run_sys_cmd(['sudo tail -f /var/log/nginx/access.log'], ssh_servers: ['dev1'], sudo: false)
    pass(t)
  end

  task update_price_check: :environment do |t|
    starting(t)
    irb_cmd([
      "Backend::App::OkielaServices::OkielaShippingFees.reload_cache_fast_delivery",
      "Backend::App::OkielaServices::OkielaShippingFees.reload_cache_normal_delivery",
      "Backend::App::OkielaServices::OkielaShippingFees.reload_cache_normal_pickup_delivery",
      "p Backend::App::OkielaServices::OkielaShippingFees.cache_fast_delivery",
      "p Backend::App::OkielaServices::OkielaShippingFees.cache_normal_delivery",
      "p Backend::App::OkielaServices::OkielaShippingFees.cache_normal_pickup_delivery"
    ])
    run_sys_cmd(['ruby ./tools/price_check/load_csv_to_json.rb'], sudo: false)
    pass(t)
  end

  task update_cache_holidays: :environment do |t|
    starting(t)
    run_sys_cmd(['ruby ./tools/update_cache_holidays.rb'], sudo: false)
    pass(t)
  end

  task force_logout: :environment do |t|
    starting(t)
    irb_cmd([
      "user = Backend::App::LogisticUsers.by_parameters(phone: '01010101017', limit: 1)",
      "Backend::App::MiscServices::ForceLogout.force_logout!(user)"
    ])
    pass(t)
  end

  task clear_statistic: :environment do |t|
    ENV['MODE'] = 'dev'
    starting(t)
    irb_cmd([
      "user = Backend::App::Users.by_parameters(phone: '0386222220')",
      "user.get_ex_client_financial_info(force_reload: true)"
    ])
    pass(t)
  end

  task reset_get_public_okiela_drop_off_address: :environment do |t|
    starting(t)
    commands = []
    commands << "file_path = $_CONFIG['system']['files']['cache_ip_address']"
    commands << 'File.open(file_path, "a+") { |file| file.truncate(0); file.write("#{{}.to_json}") }'
    irb_cmd(commands, ssh_servers: %w[dev2])
    pass(t)
  end

  task reload_price_check_cache: :environment do |t|
    starting(t)
    run_sys_cmd(['ruby ./tools/price_check/reload_cache.rb'])
    pass(t)
  end

  task reload_cache_full_power_agent_time_frame: :environment do |t|
    starting(t)
    run_sys_cmd(['./stopserver.sh', './startserver.sh', 'ruby ./tools/update_cache_full_power_agent_time_frame.rb'])
    pass(t)
  end

  task restart_system: :environment do |t|
    starting(t)
    run_sys_cmd(['./stopserver.sh', './startserver.sh'])
    pass(t)
  end
end
