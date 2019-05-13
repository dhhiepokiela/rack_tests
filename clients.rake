require_relative 'environment.rb'

namespace :clients do
  task all: :environment do |t|
    run('clients:reset_password_default')
    run('clients:login_success')
    run('clients:login_failure_wrong_pass')
    run('clients:change_password')
    run('clients:create_success')
    run('clients:create_success_with_flag_change_password')
    run('clients:create_fail_duplicate')
    run('clients:create_fail_not_permission')
    run('clients:price_check')
    run('clients:simple_price_check')
  end



  task login_success: :environment do |t|
    resp = client_login(ENV['PHONE_NUMBER'], ENV['DEFAULT_PASSWORD'])
    resp.status_200?
  end

  task manager_loged_in_success: :environment do |t|
    resp = logistic_login(ENV['PHONE_NUMBER'], ENV['DEFAULT_PASSWORD'])
    resp.status_200?
  end

  task login_failure_wrong_pass: :environment do |t|
    resp = client_login(ENV['PHONE_NUMBER'], ENV['NEW_PASSWORD'])
    resp.status_403?
  end

  task reset_password: :environment do |t|
    resp = put('auth/reset-password', {
      phone: ENV['PHONE_NUMBER'],
      client_type: :web_ex_client
    })
    resp.status_200?
  end

  task search_simple_orders: :environment do |t|
    # resp1 = get('external_clients/delivery/simple_orders', {search_term: 'nguyễn'}, api_secret)
    # puts "resp1: #{resp1['orders']['total']}"
    # resp2 = get('external_clients/delivery/simple_orders', {search_client_id: '28031951'}, api_secret)
    # puts "resp2: #{resp2['orders']['total']}"
    # resp3 = get('external_clients/delivery/simple_orders', {search_client_phone: '0322222222'}, api_secret)
    # puts "resp3: #{resp3['orders']['total']}"
    # resp5 = get('external_clients/delivery/simple_orders', {search_shop_id: '28031952'}, api_secret)
    # puts "resp5: #{resp5['orders']['total']}"

    resp4 = get('external_clients/delivery/simple_orders', {search_shop_name: 'nguyen'}, api_secret)
    puts "resp4: #{resp4['orders']['total']}"
    binding.pry
  end

  task get_order_detailt_without_purchaser_note: :environment do
    agent_login('0399999999', '123456')
    resp = get('/agents/orders/28087070?id=28087070', {}, api_token)
    puts resp['order']['purchaser_note']
  end

  task prevent_force_logout: :environment do
    client_login('0386222224', '123456')
    resp = get('auth', {}, api_token)

    resp.message_eq?('Phiên làm việc hữu hạn tìm thấy.')
    details_msg('INFO', 'CLient logged in')

    put("external_clients/settings", {}, api_token).status_200?
    resp = get('auth', {}, api_token)
    resp.message_eq?('Phiên làm việc hữu hạn tìm thấy.')
    details_msg('INFO', 'CLient still logged in')

    get("external_clients/delivery/orders/28034260?id=28034260", {}, api_token).status_200?
    resp = get('auth', {}, api_token)
    resp.message_eq?('Phiên làm việc hữu hạn tìm thấy.')
    details_msg('INFO', 'CLient still logged in')

    get("external_clients/delivery/orders/28034260/active_tracing?id=28034260", {}, api_token).status_200?
    resp = get('auth', {}, api_token)
    resp.message_eq?('Phiên làm việc hữu hạn tìm thấy.')
    details_msg('INFO', 'CLient still logged in')
  end

  task client_order_statistic: :environment do |t|
    client = Backend::App::Users.by_parameters(phone: '0386222224')
    order = Backend::App::Orders.by_id(28032798)
    Backend::App::Orders.by_parameters(client_id: client.id, return_count: true, limit: false)
  end

  task active_tracing: :environment do |t|
    client_login('0322222222', '123456')
    resp = get('/external_clients/delivery/orders/28033124/active_tracing?id=28033124', {}, api_token)
    resp.status_200?
    binding.pry
  end

  task debug_client_order_pending_cancel: :environment do |t|
    client_login('0322222222', '123456')

    params = {
      purchaser_address: 'Test',
      shop_dropoff: '584327',
      purchaser_name: 'Test Full',
      purchaser_district: 'Quận 5',
      delivery_original_price: '500000',
      is_fragile: '0',
      purchaser_phone: '0898151616',
      purchaser_ward: 'Phường 10',
      check_before_accept: '0',
      delivery_method: 'normal',
      okiela_24_7_nationwide_flag: '2',
      product_name: 'chite',
      purchaser_city: 'Hồ Chí Minh',
      package_weight: '1500',
      buyer_pay_delivery_fee: '1'
    }

    resp = post('external_clients/delivery/orders', params, api_token)
    binding.pry

    # get('external_clients/delivery/orders?client_order_status=cancelled_pending_pickup&end_date=1547612123.931990&limit=15&offset=0&start_date=1546966800.000000', {}, api_token)['orders']['items'].map{|e| e['code']}.uniq
  end

  task get_okiela_drop_off_address: :environment do |t|
    client_login('0322222222', '123456')

    # Benchmark.ips do |x|
    #   # Configure the number of seconds used during
    #   # the warmup phase (default 2) and calculation phase (default 5)
    #   x.config(:time => 5, :warmup => 2)

    #   # Typical mode, runs the block as many times as it can
    #   x.report("old") {
    #     get('powered_locations?scope=districts&super_scope_id=2', {}, api_token)
    #   }

    #   x.report("new") {
    #     get('powered_locations2?scope=districts&super_scope_id=2', {}, api_token)
    #   }

    #   # Compare the iterations per second of the various reports!
    #   x.compare!
    # end

    puts get('powered_locations?scope=districts&super_scope_id=2', {}, api_token)
    # binding.pry
  end

  task get_public_okiela_drop_off_address: :environment do |t|
    # starting(t)
    # provinces = Backend::App::MiscServices::LocationService.provinces.map { |p| p['province_id'] }
    # provinces.each do |province_id|
    #   province_name = Backend::App::MiscServices::LocationService.get_province_name(province_id: province_id)
    #   districts = Backend::App::MiscServices::LocationService.new.get_all_districts(province_id: province_id)
    #   districts.each do |district|
    #     resp = get('external_clients/delivery/get_public_okiela_drop_off_address', {
    #       city_id: province_id,
    #       district_id: district['district_id']
    #     }, api_secret)
    #     resp.status_200?
    #     details_msg('INFO', "Tỉnh: #{province_name} - Quận/Huyện: #{district['name']} - Điểm giao dịch: #{resp['address_list'].count}")
    #   end
    # end

    province_id = 43
    district_id = 495
    province_name = Backend::App::MiscServices::LocationService.get_province_name(province_id: province_id)
    district_name = Backend::App::MiscServices::LocationService.get_district_name(district_id: district_id)
    resp = get('external_clients/delivery/get_public_okiela_drop_off_address', {
      city_id: province_id,
      district_id: district_id
    }, api_secret)
    resp.status_200?
    details_msg('INFO', "EXTERNAL_CLIENTS - Tỉnh: #{province_name} - Quận/Huyện: #{district_name} - Điểm giao dịch: #{resp['address_list'].count}")

    # buyer_resp = get('orders/buyer/get_okiela_drop_off_address', {
    #   current_position_type: 'latitude_longitude',
    #   latitude: '10.8075496',
    #   longitude: '106.8591387',
    #   okiela_24_7_nationwide_flag: '2',
    #   order_id: '28021127'
    # })
    # details_msg('INFO', "BUYER_RESP - Tỉnh: #{province_name} - Quận/Huyện: 9 - Điểm giao dịch: #{buyer_resp['address_list'].count}")
    # resp.eq?(resp['address_list'].count, buyer_resp['address_list'].count)

    pass(t)
  end

  task delivery_dropoffs_by_name: :environment do |t|
    starting(t)
    phone = Backend::App::Users.by_id(583647).phone
    client_login(phone, '123456')
    details_msg('INFO', "Signed In Client #{phone}")
    resp = get('external_clients/delivery/dropoffs_by_name', { name: 'MD5007' }, api_token)
    resp.status_200?

    resp = get('external_clients/delivery/dropoffs_by_name', { name: '28019009' }, api_token)
    resp.status_200?

    resp = get('external_clients/delivery/dropoffs_by_name', { name: 'AD4013' }, api_token)
    resp.status_403?
    pass(t)


  end

  task create_single_delivery_orders: :environment do |t|
    starting(t)
    # phone = Backend::App::Users.by_id(583647).phone
    phone = '0788756946'
    client = Backend::App::Users.by_parameters(phone: phone)
    client_login(phone, '123456')
    details_msg('INFO', "Signed In Client #{phone}")

    params =  {
      okiela_24_7_nationwide_flag: '3',
      shop_dropoff: "583659",
      product_name: "Quan xa lon 1",
      delivery_original_price: "0",
      package_weight: "100",
      purchaser_name: "Chau Test",
      purchaser_phone: "0987654321",
      purchaser_address: "123 Nguyen Thi Minh Khai",
      purchaser_city: "Hồ Chí Minh",
      purchaser_district: "Quận 1",
      check_before_accept: "1",
      is_fragile: "1",
      buyer_pay_delivery_fee: "0",
      final_dropoff: "263679",
      delivery_method: "fast"
    }

    params.merge!(
      buyer_pay_delivery_fee: '1',
      delivery_code: "HHK #{rand(0..999)}",
      delivery_method: 'normal',
      delivery_original_price: '100000',
      is_fragile: '0',
      okiela_24_7_nationwide_flag: '2',
      package_weight: '10000',
      product_name: '1234',
      purchaser_address: '223',
      purchaser_city: "Hồ Chí Minh",
      purchaser_district: "Huyện Cần Giờ",
      purchaser_ward: "Xã Tam Thôn Hiệp",
      purchaser_name: 'xxHiep',
      purchaser_note: '',
      purchaser_phone: '01285286877',
      # shop_dropoff: client.own_shops[0].dropoffs[0].id
    )

    unless ENV['BYPASS_VALIDATION'].boolean_true?
      details_msg('INFO', 'Start test validation')
      required_fields = {
        okiela_24_7_nationwide_flag: 'Điểm nhận hàng',
        purchaser_name: 'Tên người nhận',
        purchaser_address: 'Địa chỉ người nhận',
        purchaser_district: 'Quận/Huyện',
        purchaser_city: 'Tỉnh/Thành phố',
        purchaser_phone: 'Số điện thoại người nhận',
        delivery_original_price: 'Tổng tiền thu hộ',
        package_weight: 'Khối lượng',
        shop_dropoff: 'Kho hàng của bạn',
        is_fragile: 'Hàng dễ vỡ',
        buyer_pay_delivery_fee: 'Người nhận trả cước'
      }

      required_fields.each do |key, value|
        details_msg('INFO', "Validation case: \"#{value}\"")
        resp = post('external_clients/delivery/orders', params.except(key.to_sym), api_token)
        resp.status_403?
        resp.message_eq?("Vui lòng nhập các thông tin sau: #{value}.")
      end
      details_msg('INFO', 'End test validation')
    end

    details_msg('INFO', 'Sending request to server')
    resp = post('external_clients/delivery/orders', params, api_token)
    resp.status_200?
    resp.message_eq?('Tạo đơn hàng thành công.')
    resp.eq?(resp['order']['okiela_24_7_nationwide_flag'], 3)
    save_order_code(resp['order']['code'])
    details_msg('INFO', "Order created ID #{resp['order']['id']} - #{resp['order']['code']} - #{params[:delivery_code]}")
    pass(t)
  end

  task reset_password_default: :environment do |t|
    starting(t)
    run('clients:reset_password', true)
    auth_params = {
      phone: ENV['PHONE_NUMBER'],
      auth_system: Backend::App::User::AUTH_SYSTEM[:client],
      limit: 1
    }

    resp = post("auth/reset-password", {
      phone: ENV['PHONE_NUMBER'],
      token: Backend::App::Users.by_parameters(auth_params).auth_reset_password,
      password: ENV['DEFAULT_PASSWORD']
    })
    pass(t)
  end

  task change_password: :environment do |t|
    run('clients:login_success', true)
    resp = put('auth/change-password', {phone: ENV['PHONE_NUMBER'], old_password: ENV['DEFAULT_PASSWORD'], new_password: ENV['NEW_PASSWORD']}, api_token)
    resp.status_201?
    resp = client_login(ENV['PHONE_NUMBER'], ENV['NEW_PASSWORD'])
    resp.status_200?
    resp = put('auth/change-password', {phone: ENV['PHONE_NUMBER'], old_password: ENV['NEW_PASSWORD'], new_password: ENV['DEFAULT_PASSWORD']}, api_token)
    resp.status_201?
    run('clients:login_success', true)
  end

  task set_allow_select_delivery_method: :environment do |t|
    starting(t)
    client = Backend::App::Users.by_parameters(phone: ENV['PHONE'])
    details_msg('INFO', "Before allow_select_delivery_method #{client.allow_select_delivery_method?}")
    client.allow_select_delivery_method = ENV['VALUE'].to_s == 'true'
    client.save
    client = Backend::App::Users.by_id(client.id, true)
    details_msg('INFO', "After allow_select_delivery_method #{client.allow_select_delivery_method?}")
    pass(t)
  end

  task create_success: :environment do |t|
    %w[078].each do |prefix|
      phone_number = "#{prefix}8#{ "%02d" % rand(100000..999999) }"
      # phone_number = '0785286828'

      resp = create_client(phone_number)
      resp.status_200?
      client = Backend::App::Users.by_id(resp['resource']['client']['id'], true)
      resp.eq?(client.discount_percent, 99)
      resp.eq?(client.paid_a_deposit?, false)

      force_reset_default_password_by_phone(phone_number) # 123456
      resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
      resp.status_201?
      resp.eq?(resp['notifications']['hint'], 'need_change_password')

      resp = put('auth/change-password', {phone: phone_number, old_password: ENV['DEFAULT_PASSWORD'], new_password: ENV['NEW_PASSWORD']}, api_token)
      resp.status_201?

      resp = put('auth/change-password', {phone: phone_number, old_password: ENV['NEW_PASSWORD'], new_password: ENV['DEFAULT_PASSWORD']}, api_token)
      resp.status_201?

      resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
      resp.eq?(resp['notifications']['hint'].blank?, true)
      resp.status_200?

      binding.pry
    end
  end

  task create_success_2: :environment do |t|
    ensure_loged_in

    1000.times do
      %w[078].each do |prefix|
        phone_number = "#{prefix}8#{ "%02d" % rand(100000..999999) }"
        begin
          resp = create_client(phone_number, false)
          force_reset_default_password_by_phone(phone_number) # 123456
          resp.status_200?

          # total_found = get("logistics/shops?limit=50&offset=0&order_by=register_oll_at&order_direction=desc&owner_type=client&search_term=#{phone_number}&status=is_unassigned", {}, api_token)
          # if total_found['shops']['total'] <= 0
          #   # binding.pry
          # end
        rescue Exception => e
          puts e.message
          # binding.pry
        end
      end
    end
  end

  task create_success: :environment do |t|
    %w[078].each do |prefix|
      phone_number = "#{prefix}8#{ "%02d" % rand(100000..999999) }"
      # phone_number = '0785286828'

      resp = create_client(phone_number)
      resp.status_200?
      client = Backend::App::Users.by_id(resp['resource']['client']['id'], true)
      resp.eq?(client.discount_percent, 99)
      resp.eq?(client.paid_a_deposit?, false)

      force_reset_default_password_by_phone(phone_number) # 123456
      resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
      resp.status_201?
      resp.eq?(resp['notifications']['hint'], 'need_change_password')

      resp = put('auth/change-password', {phone: phone_number, old_password: ENV['DEFAULT_PASSWORD'], new_password: ENV['NEW_PASSWORD']}, api_token)
      resp.status_201?

      resp = put('auth/change-password', {phone: phone_number, old_password: ENV['NEW_PASSWORD'], new_password: ENV['DEFAULT_PASSWORD']}, api_token)
      resp.status_201?

      resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
      resp.eq?(resp['notifications']['hint'].blank?, true)
      resp.status_200?
    end
  end

  task update_client: :environment do |t|
    starting(t)
    ensure_loged_in
    client_id = '28036154'

    cases = [
      { discount_percent: '26', paid_a_deposit: 'false' },
      { discount_percent: '50', paid_a_deposit: 'true' },
      { discount_percent: '10', paid_a_deposit: 'false' },
      { discount_percent: '0', paid_a_deposit: 'false' },
      { discount_percent: '29', paid_a_deposit: 'true' },
    ]

    cases.each do |test_case|
      details_msg('INFO', "Loading test case: #{test_case}")
      resp = put("external_clients/profile/#{client_id}", test_case, api_token)
      resp.status_200?
      client = Backend::App::Users.by_id(client_id, true)
      resp.eq?(client.discount_percent, test_case[:discount_percent].to_i)
      resp.eq?(client.paid_a_deposit?, test_case[:paid_a_deposit].boolean_true?)
    end

    resp = put("external_clients/profile/#{client_id}", {}, api_token)
    client = Backend::App::Users.by_id(client_id, true)
    resp.eq?(client.discount_percent, cases[-1][:discount_percent].to_i)
    resp.eq?(client.paid_a_deposit?, cases[-1][:paid_a_deposit].boolean_true?)

    cases_fails = [
      { discount_percent: 'xx' },
      { discount_percent: '-1' },
      { discount_percent: '101' }
    ]

    cases_fails.each do |test_case|
      details_msg('INFO', "Loading test case: #{test_case}")
      resp = put("external_clients/profile/#{client_id}", test_case, api_token)
      resp.status_403?
    end

    pass(t)
  end

  task create_success_with_flag_change_password: :environment do |t|
    phone_number = "078528#{ "%02d" % rand(1000..9999) }"

    resp = create_client(phone_number)
    resp.message_eq?('Tạo client thành công')

    force_reset_default_password_by_phone(phone_number) # 123456
    resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
    resp.eq?(resp['notifications']['hint'], 'need_change_password')

    resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
    resp.eq?(resp['notifications']['hint'], 'need_change_password')

    resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
    resp.eq?(resp['notifications']['hint'], 'need_change_password')
  end

  task create_fail_duplicate: :environment do |t|
    resp = create_client(ENV['PHONE_NUMBER'])
    resp.status_403?
  end

  task create_fail_not_permission: :environment do |t|
    run('clients:login_success', true)
    resp = create_client("078528#{ "%02d" % rand(1000..9999) }", false)
    resp.status_403?
  end

  task find_customer_basic_info: :environment do |t|
    client_login('0788756946', '123456')
    # binding.pry
    resp = get('external_clients/delivery/purchaser_info', {search_term: '0', search_field: 'purchaser_phone', okiela_24_7_nationwide_flag: 3 }, api_token)

    resp.status_200?
    binding.pry
  end

  task simple_price_check: :environment do |t|
    (1..63).to_a.map { |id| { package_weight: "#{id}00", city_id: id } }.each do |params|
      p "Province #{fect_province_and_district_name({city_id: params[:city_id]})} is processing ..."
      resp = get('external_clients/delivery/simple_price_check', params, api_secret)
      resp.status_200?
    end

    # Province not available
    (64..65).to_a.map { |id| { package_weight: "#{id}00", city_id: id } }.each do |params|
      p "Province #{fect_province_and_district_name({city_id: params[:city_id].presence || 'Unknown'})} is processing ..."
      resp = get('external_clients/delivery/simple_price_check', params, api_secret)
      resp.status_403?
    end

    success_msg('API external_clients/delivery/simple_price_check is OK')
  end

  task expected_delivery_times: :environment do
    params = {
      client_id: 28036484,
      package_weight: '2000',
      size: '10.6x5.1x30',
      shop_dropoff_id: '27993016',
      city_id: 50,
      district_id: 563
    }
    a = Backend::App::OrderServices::OkieLaDeliveryFeeGenerator.new(params).process
    binding.pry
  end

  task price_check: :environment do |t|
    # client = run('clients:login_success', true)
    client_login('0785286466', ENV['DEFAULT_PASSWORD'])
    @tolerance = 5 # minutes
    @test_validation = false

    params = {
      package_weight: '2000',
      size: '10.6x5.1x30',
      shop_dropoff_id: '27993016',
      city_id: 50,
      district_id: 563
    }

    resp = get('external_clients/delivery/price_check', params.merge(city_id: 50, district_id: 566), api_token)

    # # # = = = = TEST VALIDATION = = = =
    if @test_validation
      success_msg('Validation tesing: Vui lòng nhập các thông tin')
      %i[package_weight size shop_dropoff_id city_id district_id].each do |key|
        resp = get('external_clients/delivery/price_check', params.except(key), api_token)
        resp.status_403?
        resp.message_eq?("Vui lòng nhập các thông tin sau: #{key}.")
      end

      success_msg('Validation tesing: Kích thước không hợp lệ')
      %w[10.6xxx 10.6x5.1 10.6x5.1xff 55x11x33 11x22x70].each do |key|
        resp = get('external_clients/delivery/price_check', params.merge(size: key), api_token)
        resp.status_403?
        resp.message_eq?('Kích thước không hợp lệ')
      end

      success_msg('Validation tesing: Khối lượng không hợp lệ')
      %w[20001 -1 0].each do |key|
        resp = get('external_clients/delivery/price_check', params.merge(package_weight: key), api_token)
        resp.status_403?
        resp.message_eq?('Khối lượng không hợp lệ')
      end

      success_msg('Validation tesing: Địa chỉ Kho hàng không hợp lệ')
      %w[599672 584425 583271].each do |key|
        resp = get('external_clients/delivery/price_check', params.merge(shop_dropoff_id: key), api_token)
        resp.status_403?
        resp.message_eq?('Địa chỉ Kho hàng không hợp lệ')
      end

      success_msg('Validation tesing: Địa chỉ Nhận hàng không được hỗ trợ')
      %w[1].each do |key|
        resp = get('external_clients/delivery/price_check', params.merge(city_id: key), api_token)
        resp.status_403?
        resp.message_eq?('Địa chỉ Nhận hàng không được hỗ trợ')
      end

      success_msg('Validation tesing: Địa chỉ Nhận hàng không được hỗ trợ')
      %w[1].each do |key|
        resp = get('external_clients/delivery/price_check', params.merge(district_id: key), api_token)
        resp.status_403?
        resp.message_eq?('Địa chỉ Nhận hàng không được hỗ trợ')
      end

      success_msg('Validation tesing: Loại dịch vụ không hợp lệ')
      resp = get('external_clients/delivery/price_check', params.merge(delivery_method: 'test'), api_token)
      resp.status_403?
      resp.message_eq?('Loại dịch vụ không hợp lệ')

      success_msg('Validation tesing: Default params is valid')
      resp = get('external_clients/delivery/price_check', params, api_token)
      resp.status_200?
    end
    # # = = = = END TEST VALIDATION = = = =

    # # = = = = START TEST RESPONSE RESULT = = = =
    success_msg('Test response results with delivery method and okiela_24_7_nationwide_flag: 3 results')
    resp = get('external_clients/delivery/price_check', params, api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 3)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["normal", "okiela_24_7_drop_off_deliver"], ["fast", "okiela_24_7_drop_off_deliver"], ["normal", "okiela_24_7_drop_off_pickup"]])

    extra_params = { delivery_method: 'normal' }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 2 results ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 2)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["normal", "okiela_24_7_drop_off_deliver"], ["normal", "okiela_24_7_drop_off_pickup"]])

    extra_params = { delivery_method: 'normal', okiela_24_7_nationwide_flag: '2' }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 1 results ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 1)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["normal", "okiela_24_7_drop_off_deliver"]])

    extra_params = { delivery_method: 'normal', okiela_24_7_nationwide_flag: '3' }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 1 results ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 1)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["normal", "okiela_24_7_drop_off_pickup"]])

    extra_params = { delivery_method: 'fast', okiela_24_7_nationwide_flag: '3' }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 1 results ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 1)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["fast", "okiela_24_7_drop_off_deliver"]])

    extra_params = { delivery_method: 'fast' }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 1 results ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 1)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["fast", "okiela_24_7_drop_off_deliver"]])

    extra_params = { delivery_method: 'fast', okiela_24_7_nationwide_flag: '2' }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 1 results ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 1)
    resp.eq?(resp['price_check'].map{|e| [e['delivery_method'], e['delivery_oll_type']]}, [["fast", "okiela_24_7_drop_off_deliver"]])

    extra_params = { delivery_method: 'normal', district_id: 566, city_id: 50 }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 1 results and ignore GIAO CHẬM GẦN NHÀ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 1)

    extra_params = { district_id: 566, city_id: 50 }
    success_msg("Test response results with delivery method and oll_type (#{extra_params}): 2 results and ignore GIAO CHẬM GẦN NHÀ")
    resp = get('external_clients/delivery/price_check', params.merge(extra_params), api_token)
    resp.status_200?
    resp.eq?(resp['price_check'].count, 2)
    # # = = = = END TEST RESPONSE RESULT = = = =

    # = = = = TEST DATA = = = =
    kien_xuong =
      build_test_data_json({
        district_id: 281,
        province_id: 25,
        normal_cost_level_1: 37800,
        normal_cost_level_2: 42600,
        normal_cost_level_3: 49300,
        normal_cost_level_4: 60500,
        normal_cost_extra: 2100,
        fast_cost_level_1: 61200,
        fast_cost_level_2: 80300,
        fast_cost_level_3: 97800,
        fast_cost_level_4: 114500,
        fast_cost_extra: 8500,
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 60500 + 2100 * 8,
        custom_fast_cost_expect: 114500 + 8500 * 8,
        normal_deliver_time: '120-168|144-192',
        fast_deliver_time: '72-96|96-120'
      })

    kien_xuong_with_pickup_date =
      build_test_data_json({
        district_id: 281,
        province_id: 25,
        normal_cost_level_1: 37800,
        normal_cost_level_2: 42600,
        normal_cost_level_3: 49300,
        normal_cost_level_4: 60500,
        normal_cost_extra: 2100,
        fast_cost_level_1: 61200,
        fast_cost_level_2: 80300,
        fast_cost_level_3: 97800,
        fast_cost_level_4: 114500,
        fast_cost_extra: 8500,
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 60500 + 2100 * 8,
        custom_fast_cost_expect: 114500 + 8500 * 8,
        pickup_date: 3.days_from_now.strftime('%Y-%m-%d %H:%M'),
        normal_deliver_time: '120-168|144-192',
        fast_deliver_time: '72-96|96-120'
      })

    chau_doc =
      build_test_data_json({ # Châu Đốc
        district_id: 564,
        province_id: 50,
        normal_cost_level_1: 23800,
        normal_cost_level_2: 28200,
        normal_cost_level_3: 32600,
        normal_cost_level_4: 37000,
        normal_cost_extra: 4400,
        fast_cost_level_1: 43800,
        fast_cost_level_2: 54100,
        fast_cost_level_3: 63000,
        fast_cost_level_4: 74400,
        fast_cost_extra: 4300,
        custom_package_weight: 20,
        custom_normal_cost_expect: 37000 + 4400 * 36,
        custom_fast_cost_expect: 74400 + 4300 * 36,
        normal_deliver_time: '24-48|48-72',
        fast_deliver_time: '24-48|48-72'
      })

    chau_thanh_a =
      build_test_data_json({ # Châu Thành A - Hậu Giang
        district_id: 686,
        province_id: 63,
        normal_cost_level_1: 33800,
        normal_cost_level_2: 38200,
        normal_cost_level_3: 42600,
        normal_cost_level_4: 47000,
        normal_cost_extra: 4400,
        fast_cost_level_1: 54900,
        fast_cost_level_2: 66900,
        fast_cost_level_3: 77600,
        fast_cost_level_4: 91300,
        fast_cost_extra: 4300,
        custom_package_weight: 19.5,
        custom_normal_cost_expect: 47000 + 4400 * 35,
        custom_fast_cost_expect: 91300 + 4300 * 35,
        normal_deliver_time: '96-144|120-168',
        fast_deliver_time: '48-72|72-96'
      })

    tan_chau =
      build_test_data_json({ # Tân Châu An Giang
        district_id: 566,
        province_id: 50,
        normal_cost_level_1: 33800,
        normal_cost_level_2: 38200,
        normal_cost_level_3: 42600,
        normal_cost_level_4: 47000,
        normal_cost_extra: 4400,
        fast_cost_level_1: 54900,
        fast_cost_level_2: 66900,
        fast_cost_level_3: 77600,
        fast_cost_level_4: 91300,
        fast_cost_extra: 4300,
        custom_package_weight: 19.5,
        custom_normal_cost_expect: 49500 + 4400 * 35,
        custom_fast_cost_expect: 91300 + 4300 * 35,
        normal_deliver_time: '96-144|120-168',
        fast_deliver_time: '48-72|72-96'
      })

    vinh_yen =
      build_test_data_json({
        district_id: 186,
        province_id: 16,
        normal_cost_level_1: 30100,
        normal_cost_level_2: 34320,
        normal_cost_level_3: 44300,
        normal_cost_level_4: 49500,
        normal_cost_extra: 2100,
        fast_cost_level_1: 49300,
        fast_cost_level_2: 65500,
        fast_cost_level_3: 79800,
        fast_cost_level_4: 93700,
        fast_cost_extra: 8500,
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 49500 + 2100 * 8,
        custom_fast_cost_expect: 93700 + 8500 * 8,
        normal_deliver_time: '120-168|144-192',
        fast_deliver_time: '48-72|72-96'
      })

    thanh_pho_dien_bien =
      build_test_data_json({
        district_id: 664,
        province_id: 61,
        normal_cost_level_1: 30100,
        normal_cost_level_2: 34320,
        normal_cost_level_3: 44300,
        normal_cost_level_4: 49500,
        normal_cost_extra: 2100,
        fast_cost_level_1: 49300,
        fast_cost_level_2: 65500,
        fast_cost_level_3: 79800,
        fast_cost_level_4: 93700,
        fast_cost_extra: 8500,
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 49500 + 2100 * 8,
        custom_fast_cost_expect: 93700 + 8500 * 8,
        normal_deliver_time: '120-168|144-192',
        fast_deliver_time: '48-72|72-96'
      })

    huyen_dien_bien =
      build_test_data_json({
        district_id: 666,
        province_id: 61,
        normal_cost_level_1: 37800,
        normal_cost_level_2: 42600,
        normal_cost_level_3: 49300,
        normal_cost_level_4: 60500,
        normal_cost_extra: 2100,
        normal_deliver_time: '120-168|144-192',
        fast_cost_level_1: 61200,
        fast_cost_level_2: 80300,
        fast_cost_level_3: 97800,
        fast_cost_level_4: 114500,
        fast_cost_extra: 8500,
        fast_deliver_time: '72-96|96-120',
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 60500 + 2100 * 8,
        custom_fast_cost_expect: 114500 + 8500 * 8
      })

    dien_bien_dong =
      build_test_data_json({
        district_id: 670,
        province_id: 61,
        normal_cost_level_1: 37800,
        normal_cost_level_2: 42600,
        normal_cost_level_3: 49300,
        normal_cost_level_4: 60500,
        normal_cost_extra: 2100,
        normal_deliver_time: '120-168|144-192',
        fast_cost_level_1: 61200,
        fast_cost_level_2: 80300,
        fast_cost_level_3: 97800,
        fast_cost_level_4: 114500,
        fast_cost_extra: 8500,
        fast_deliver_time: '72-96|96-120',
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 60500 + 2100 * 8,
        custom_fast_cost_expect: 114500 + 8500 * 8
      })

    quynh_coi =
      build_test_data_json({
        district_id: 728,
        province_id: 25,
        normal_cost_level_1: 37800,
        normal_cost_level_2: 42600,
        normal_cost_level_3: 49300,
        normal_cost_level_4: 60500,
        normal_cost_extra: 2100,
        normal_deliver_time: '120-168|144-192',
        fast_cost_level_1: 61200,
        fast_cost_level_2: 80300,
        fast_cost_level_3: 97800,
        fast_cost_level_4: 114500,
        fast_cost_extra: 8500,
        fast_deliver_time: '72-96|96-120',
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 60500 + 2100 * 8,
        custom_fast_cost_expect: 114500 + 8500 * 8
      })

    hcm = # HCM Tan Binh
      build_test_data_json({
        hcm: true,
        district_id: 43,
        province_id: 2,
        normal_cost_level_1: 20_000,
        normal_cost_level_2: 20_000,
        normal_cost_level_3: 20_000,
        normal_cost_level_4: 20_000,
        normal_cost_extra: 2180,
        fast_cost_level_1: 20_000,
        fast_cost_level_2: 20_000,
        fast_cost_level_3: 20_000,
        fast_cost_level_4: 20_000,
        fast_cost_extra: 2180,
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 20_000 + 2180 * 6,
        custom_fast_cost_expect: 20_000 + 2180 * 6,
        normal_deliver_time: '24-48|48-72',
        fast_deliver_time: '24-48|48-72'
      })

    hcm_can_gio = # HCM Huyện Cần Giờ
      build_test_data_json({
        hcm: true,
        district_id: 53,
        province_id: 2,
        normal_cost_level_1: 20_000,
        normal_cost_level_2: 20_000,
        normal_cost_level_3: 20_000,
        normal_cost_level_4: 20_000,
        normal_cost_extra: 2180,
        fast_cost_level_1: 20_000,
        fast_cost_level_2: 20_000,
        fast_cost_level_3: 20_000,
        fast_cost_level_4: 20_000,
        fast_cost_extra: 2180,
        custom_package_weight: 5.8,
        custom_normal_cost_expect: 20_000 + 2180 * 6,
        custom_fast_cost_expect: 20_000 + 2180 * 6,
        normal_deliver_time: '24-48|48-72',
        fast_deliver_time: '24-48|48-72'
      })

    data_tests = []
    data_tests << kien_xuong_with_pickup_date
    data_tests << kien_xuong
    data_tests << vinh_yen
    data_tests << chau_doc
    data_tests << thanh_pho_dien_bien
    data_tests << huyen_dien_bien
    data_tests << dien_bien_dong
    data_tests << chau_thanh_a
    data_tests << quynh_coi
    data_tests << hcm
    data_tests << hcm_can_gio

    client = client_login(ENV['PHONE_NUMBER'], ENV['DEFAULT_PASSWORD'])

    client = Backend::App::Users.by_id(28020177).phone
    data_tests.each do |data_test|
      data_test.each do |test_case|
        success_msg "Processing test case: #{fect_province_and_district_name(test_case[:data])} - #{test_case[:data]} ..."
        success_msg "_ _ _ Normal expected: #{test_case[:expected][:normal]}"
        success_msg "_ _ _ Fast expected: #{test_case[:expected][:fast]}"
        params[:check_free_deliveries] = true
        resp = get('external_clients/delivery/price_check', params.merge(test_case[:data]), api_token)
        resp.status_200?
        resp['price_check'].each do |delivery_method|
          begin
            expected_deliver_time = Time.parse(delivery_method['expected_deliver_time'], '%Y-%m-%d %H:%M:%S %z')
            expected_deliver_max_time = Time.parse(delivery_method['expected_deliver_max_time'], '%Y-%m-%d %H:%M:%S %z')
            key = delivery_method['delivery_method'].to_sym
            delivery_method_name =
              if key == :normal
                if delivery_method['delivery_oll_type'] == 'okiela_24_7_drop_off_pickup'
                  'DỊCH VỤ BÌNH THƯỜNG - GẦN NHÀ'
                else
                  'DỊCH VỤ BÌNH THƯỜNG - TẬN TAY'
                end
              else
                'DỊCH VỤ NHANH - TẬN TAY'
              end

            resp.eq?(delivery_method_name, delivery_method['delivery_method_name'])
            resp.eq?(delivery_method['okiela_24_7_delivery_fee'].to_i, test_case[:expected][key][:cost].to_i)
            resp.lt?(expected_deliver_time, test_case[:expected][key][:expected_deliver_time])
            resp.gt?(expected_deliver_time, test_case[:expected][key][:expected_deliver_time] - (@tolerance * 60 + 1))
            resp.lt?(expected_deliver_max_time, test_case[:expected][key][:expected_deliver_max_time])
            resp.gt?(expected_deliver_max_time, test_case[:expected][key][:expected_deliver_max_time] - (@tolerance * 60 + 1))
          rescue Exception => e
            error_msg("Fail: #{e}")
            # binding.pry
          end
        end
      end
    end
    # = = = = END TEST DATA = = = =
  end

  def parse_datetime_from_hour(base = Time.now, hour = 0, extra = 0)
    (base + (hour * 60 * 60) + (extra * 60))
  end

  def fect_province_and_district_name(data)
    [
      Backend::App::MiscServices::LocationService.get_province_name(province_id: data[:city_id]),
      Backend::App::MiscServices::LocationService.get_district_name(district_id: data[:district_id])
    ].reject(&:blank?).join(' - ')
  end

  def build_test_data_json(options)
    idx = Time.now.strftime('%H').to_i < 11 ? 0 : 1
    base_time = options[:pickup_date].present? ? Time.parse(options[:pickup_date], '%Y-%m-%d %H:%M %z') : Time.now
    normal_expected_deliver_time, normal_expected_deliver_max_time = options[:normal_deliver_time].split('|')[idx].split('-').map(&:to_i)
    fast_expected_deliver_time, fast_expected_deliver_max_time = options[:fast_deliver_time].split('|')[idx].split('-').map(&:to_i)
    options[:normal_expected_deliver_time] = parse_datetime_from_hour(base_time, normal_expected_deliver_time, @tolerance)
    options[:normal_expected_deliver_max_time] = parse_datetime_from_hour(base_time, normal_expected_deliver_max_time, @tolerance)
    options[:fast_expected_deliver_time] = parse_datetime_from_hour(base_time, fast_expected_deliver_time, @tolerance)
    options[:fast_expected_deliver_max_time] = parse_datetime_from_hour(base_time, fast_expected_deliver_max_time, @tolerance)

    [
      {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: rand(0.1..0.5) * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:normal_cost_level_1],
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:fast_cost_level_1],
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }, {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: rand(0.6..1) * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:normal_cost_level_2],
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:fast_cost_level_2],
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }, {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: rand(1.1..1.5) * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:normal_cost_level_3],
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:fast_cost_level_3],
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }, {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: rand(1.6..2) * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:normal_cost_level_4],
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:fast_cost_level_4],
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }, {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: rand(2.1..2.5) * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:hcm] ? options[:normal_cost_level_4] : options[:normal_cost_level_4] + options[:normal_cost_extra],
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:hcm] ? options[:fast_cost_level_4] : options[:fast_cost_level_4] + options[:fast_cost_extra],
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }, {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: rand(2.6..3) * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:hcm] ? options[:normal_cost_level_4] : options[:normal_cost_level_4] + options[:normal_cost_extra] * 2,
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:hcm] ? options[:fast_cost_level_4] : options[:fast_cost_level_4] + options[:fast_cost_extra] * 2,
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }, {
        data: {
          district_id: options[:district_id],
          city_id: options[:province_id],
          pickup_date: options[:pickup_date],
          package_weight: options[:custom_package_weight] * 1000 # grams
        },
        expected: {
          normal: {
            cost: options[:custom_normal_cost_expect],
            expected_deliver_time: options[:normal_expected_deliver_time],
            expected_deliver_max_time: options[:normal_expected_deliver_max_time]
          },
          fast: {
            cost: options[:custom_fast_cost_expect],
            expected_deliver_time: options[:fast_expected_deliver_time],
            expected_deliver_max_time: options[:fast_expected_deliver_max_time]
          }
        }
      }
    ]
  end

  def create_client(phone_number, force_login = true)
    ensure_loged_in if force_login
    suffix = phone_number[7..11]
    puts "Client's phone is creating: #{phone_number}".colorize(:light_red)

    client_params = {
      forename: 'Tester',
      surname: "Client #{suffix}",
      phone: phone_number,
      email: "client_tester_#{suffix}_#{Time.now.to_i}@okiela.com",
      client_free_deliveries_number: 2,
      shop_name: "Shop ##{suffix}",
      shop_street: "#{suffix} Tan Ky Tan Quy",
      shop_ward: 'Phuong 6',
      shop_town: '',
      shop_district: 'Quận Tân Bình',
      shop_city: 'HCM',
      discount_percent: '99',
      paid_a_deposit: "1",
      client_free_expired_date: "15/03/2019"
    }

    post('external_clients', client_params, api_token)
  end

  def ensure_loged_in
    run('clients:manager_loged_in_success', true)
  end
end
