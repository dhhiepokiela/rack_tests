require_relative 'environment.rb'

namespace :system do
  task console: :environment do |t|
    # order = Backend::App::Orders.by_id(543095)
    # resp = agent_login('0788822233', '123456')
    # resp.status_200?
    # Backend::App::FinanceServices::FinanceDropOffs.new({
    #   search_term: 'XXX',
    #   start_date: 1457300949,
    #   end_date: 1557300949,
    #   min_amount: 100,
    #   max_amount: 10000,
    #   order_by: 'name'
    # }).process
    binding.pry
  end

  task test_command: :environment do |t|
    binding.pry
    dashboard_logistic_login!

    # order_codes = ['MD63692082', 'MD12692082', 'MD11292082']
    order_codes = ['MD98804082']
    order_codes.each do |order_code|
      order = Backend::App::Orders.by_parameters(code: order_code)
      # address_params = {id: order.entity_id, city: "Hồ Chí Minh", district: "Quận 1", id: "28015270", latitude: "10.8075496", longitude: "106.85913870000002", street: "134 Lê Thị Bạch Cát", ward: "phường 1"}
      # resp = put("logistics/orders/#{order.entity_id}/update_purchaser_address", address_params, api_token)

      # sleep(3)
      # order = Backend::App::Orders.by_id(order.entity_id, true)
      ghn_service = Backend::App::GHNServices::GHNAPIService.new(order, dashboard_user_id: 28049522)
      ghn_service.create_giaohangnhanh_order
    end
    # binding.pry

    # # binding.pry
    # # order = Backend::App::Orders.by_id(order.entity_id, true)
    # # ghn_service = Backend::App::GHNServices::GHNAPIService.new(order, dashboard_user_id: 28049522)

    # binding.pry
    # resp = put("logistics/orders/#{order.entity_id}/update_purchaser_phone", { id: order.entity_id, phone: '0788888888' }, api_token)
    # # binding.pry

    # sleep(1)
    # ghn_service.update_giaohangnhanh_order(data: {CustomerName: 'Hiep Dinh', ActionType: 'CustomerName'})
    # # binding.pry

    # sleep(1)
    # ghn_service.update_giaohangnhanh_order(data: {CustomerPhone: '0788888889', ActionType: 'CustomerPhone'})
    # # binding.pry

    # sleep(1)
    # resp = put("logistics/orders/#{order.entity_id}/update_purchaser_address", address_params, api_token)
    # # binding.pry

    # # %w[ReadyToPick Picking Storing Delivering Delivered WaitingToFinish Finish].each do |status|
    # # %w[ReadyToPick Picking Storing Delivering Return].each do |status|
    # %w[ReadyToPick Picking Storing Delivering Return Delivering Delivered WaitingToFinish Finish].each do |status|
    #   puts "CurrentStatus #{status}"
    #   sleep(1)
    #   puts post('callbacks/giaohangnhanh_order_updated', {'data' => {'CurrentStatus' => status, 'ExternalCode' => order_code}}, api_token)
    # end

    # # sleep(1)
    # # ghn_service.cancel_giaohangnhanh_order




    # resp = post('logistics/manager_update_package_weight', { email: 'hoanghiepitvnn@gmail.com', list_orders: "[{\"code\": \"#{order_code}\", \"weight\": \"1900\"}]" }, api_token)
    # binding.pry

    # resp = post('logistics/manager_update_delivery_original_price', { list_orders: "[{\"code\": \"#{order_code}\", \"price\": \"155000\"}]" }, api_token)
    # binding.pry

    # resp = put('logistics/manager_update_client_buyer_pay_delivery_fee', { buyer_pay_delivery_fee: false, order_code: order_code }, api_token)



    # Backend::App::GHNServices::GHNAPIService.new(from_district_id: 31, to_district_id: 39, weight: 10000, service_id: 53319).calculate_fee
    # Backend::App::GHNServices::GHNAPIService.set_giaohangnhanh_callback_config!
    # Backend::App::GHNServices::GHNAPIService.update_giaohangnhanh_districts!
    # Backend::App::GHNServices::GHNAPIService.create_hubs({
    #   name: "GHN - TPT",
    #   phone: "0988111111",
    #   address: "140 Lê Trọng Tấn",
    #   district_id: 43,
    #   email: "hiep.dinh@test-okie.com",
    #   is_main: true,
    #   latitude: 10.0000001,
    #   longitude: 108.00000032
    # })
    # order = Backend::App::Orders.by_id(28050098)
    # p Backend::App::GHNServices::GHNAPIService.new(order).create_giaohangnhanh_order
    # Backend::App::GHNServices::GHNAPIService.new(order).update_giaohangnhanh_order(data: {
    #   customer_name: 'hh abc'
    # })
    # Backend::App::GHNServices::GHNAPIService.new(order).cancel_giaohangnhanh_order
    # binding.pry
    # params = {
    #   package_weight: '2000',
    #   size: '10.6x5.1x30',
    #   shop_dropoff_id: '27993016',
    #   city_id: 50,
    #   district_id: 563
    # }

    # resp = get('external_clients/delivery/price_check', params, api_token)
    # resp.status_200?
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

  task re_generate_locations: :environment do |t|
    starting(t)
    run_sys_cmd(['ruby tools/locations/export_json.rb'], sudo: false)
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

  task send_email_client_shop_criteria_to_salesman: :environment do |t|
    starting(t)
    run_sys_cmd(['rake survey:send_email_client_shop_criteria_to_salesman'], ssh_servers: ['dev1'])
    pass(t)
  end

  task reload_cache_full_power_agent_time_frame: :environment do |t|
    starting(t)
    run_sys_cmd(['./stopserver.sh', './startserver.sh', 'ruby ./tools/update_cache_full_power_agent_time_frame.rb'])
    pass(t)
  end

  task restart_system: :environment do |t|
    starting(t)
    servers = ENV['SERVERS'].to_s.split(',')
    servers = %w[dev1 dev2] if servers.empty?
    run_sys_cmd(['./stopserver.sh', './startserver.sh'], ssh_servers: servers)
    pass(t)
  end
end
