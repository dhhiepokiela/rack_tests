require_relative 'environment.rb'

namespace :orders do
  task clean_unsynchronised_orders_on_es: :environment do |t| 
    offset = 500
    unsynchronised_orders = []

    (0..500).to_a.each do |page|
      puts "Page #{page} - unsynchronised orders: #{unsynchronised_orders.count}"

      order_ids_on_es =
        HTTParty.post("http://api-online-dev.okiela.com:9200/okiela/order/_search",
          query: {
            "size" => offset, 
            "from" => page * offset, 
            "_source" => ["code"]
        })["hits"]["hits"].map { |e| e['_source']['id'].presence }.compact

      if order_ids_on_es.any?
        sql =
          <<-SQL
            select entity_id
            from res_order
            where entity_id IN (#{order_ids_on_es.join(',')})
          SQL

        order_ids = DatabasePool.get_connector.query(sql: sql).to_a.map { |e| e[:entity_id] }
        unsynchronised_orders.concat(order_ids_on_es - order_ids).uniq!
      else
        details_msg('INFO', 'Scan done')
        details_msg('INFO', "Removing #{unsynchronised_orders.count} unsynchronised orders.\n")
        unsynchronised_orders.each_with_index do |order_id, index|
          details_msg('SYSTEM', "Removing order ##{order_id} on ES #{index + 1}/#{unsynchronised_orders.count}")
          HTTParty.delete("http://api-online-dev.okiela.com:9200/okiela/order/#{order_id}")
        end
        details_msg('INFO', 'All removed')
        break
      end      
    end
  end

  task client_report: :environment do |t|
    irb_cmd([
      Backend::App::AnalyticsServices::KpiClientOrderCombinedStatistic.new(start_date: Time.parse('2018-01-01'), end_date: Time.now, email: 'score_kpi_dev@okiela.com').gather_report,
      Backend::App::AnalyticsServices::KpiClientOrderCombinedStatistic.new(start_date: Time.parse('2018-01-01'), end_date: Time.now, email: 'phai.nguyen@okiela.com').gather_report,
      Backend::App::AnalyticsServices::KpiClientOrderCombinedStatistic.new(start_date: Time.parse('2018-01-01'), end_date: Time.now, email: 'hoanghiepitvnn@gmail.com').gather_report
    ])
  end

  task logistic_order_work_flow: :environment do |t|
    starting(t)
    dashboard_logistic_login!

    ENV['ID'] = Backend::App::Orders.by_parameters(code: ENV['CODE']).id.to_s if ENV['ID'].blank? && ENV['CODE'].present?
    order = Backend::App::Orders.by_id(ENV['ID'], true)
    order.shop_id = 28039568
    order.save

    ENV['DISPLAY_TIMES'] = '1' # FOR display_client_order_statistics
    run('orders:order_details')
    run('orders:display_client_order_statistics')

    dashboard_logistic_login!
    resp = post('logistics/manager_change_oll_order_type', { 
      order_id: order.id, 
      new_okiela_24_7_nationwide_flag: 2
    }, api_token) 

    current_user = dashboard_logistic_login!
    default_final_dropoff_id = 28012327
    # default_pickup_driver_id = 391202 # Chau Angela Nguyen
    default_pickup_driver_id = 582233
    default_deliver_driver_id = 582233 # Sabrih Hoang

    resp = get("logistics/orders/#{order.id}/get_okiela_drop_off_address", {}, api_token)
    resp.status_200_or_201?
    final_dropoff_ids = resp['shop_dropoffs'].map{|e| e['id']}
    final_dropoff_id = final_dropoff_ids.include?(default_final_dropoff_id) ? default_final_dropoff_id : final_dropoff_ids[0]
    final_dropoff = resp['shop_dropoffs'].select{|d| d['id'] == final_dropoff_id}[0]
    dropoff_address = %w[street ward district city].map{|a| final_dropoff['address'][a] }.join(', ')
    details_msg('INFO', "Set final_dropoff: #{final_dropoff['name']} - #{final_dropoff['phone']} - #{dropoff_address}")

    resp = get("logistics/orders/#{order.id}/assignable_drivers", {
      assign_type: 'pickup',
      final_dropoff_id: final_dropoff_id,
      id: order.id
    }, api_token)
    resp.status_200_or_201?
    pickup_driver_ids = resp['logistic_user']['items'].map{|e| e['id']}
    pickup_driver_id = pickup_driver_ids.include?(default_pickup_driver_id) ? default_pickup_driver_id : pickup_driver_ids[0]
    pickup_selected_driver = resp['logistic_user']['items'].select{|d| d['id'] == pickup_driver_id}[0]
    pickup_driver_text = "#{pickup_selected_driver['surname']} #{pickup_selected_driver['forename']} - #{pickup_selected_driver['phone']}"
    details_msg('INFO', "Assign pickup driver to: #{pickup_driver_text}")

    resp = get("logistics/orders/#{order.id}/assignable_drivers", {
      assign_type: 'deliver',
      final_dropoff_id: final_dropoff_id,
      id: order.id
    }, api_token)
    resp.status_200_or_201?
    deliver_driver_ids = resp['logistic_user']['items'].map{|e| e['id']}
    deliver_driver_id = deliver_driver_ids.include?(default_deliver_driver_id) ? default_deliver_driver_id : deliver_driver_ids[0]
    deliver_selected_driver = resp['logistic_user']['items'].select{|d| d['id'] == deliver_driver_id}[0]
    details_msg('INFO', "Assign deliver driver to: #{deliver_selected_driver['surname']} #{deliver_selected_driver['forename']} - #{deliver_selected_driver['phone']}")

    params_update_order = {
      deliver_driver_id: deliver_driver_id,
      expect_pickup_time: 'Wed+Nov+14+2018+12:00:00+GMT%2B0700+(Indochina+Time)',
      final_dropoff_id: final_dropoff_id,
      order_id: order.id,
      pickup_driver_id: pickup_driver_id,
      shop_dropoff: order.shop_dropoff_obj.id
    }

    resp = put('logistics/logistic_assign_driver', params_update_order, api_token)
    resp.status_200_or_201?
    resp = put('logistics/dashboard_confirm_order', {order_id: order.id }, api_token)
    resp.status_200_or_201?
    details_msg('INFO', "Order is updated with: #{params_update_order.to_json}")

    details_msg('INFO', "Driver #{pickup_driver_text} picking up order #{order.code}")
    logistic_login(pickup_selected_driver['phone'], '123456')
    resp = put('logistics/staff_confirm_keep_order', {order_id: order.id}, api_token)
    resp.status_200_or_201?

    # details_msg('INFO', "Driver #{pickup_driver_text} delivered order ##{order.code} to dropoff")
    # resp = put('logistics/staff_confirm_delivered_order', {order_id: order.id}, api_token)
    # resp.status_200_or_201?

    # run('orders:order_details')
    # run('orders:display_client_order_statistics')
    pass(t)
  end

  # Test update_mode_of_payment 'Không có địa điểm nào gần tôi'
  task update_mode_of_payment: :environment do |t|
    buyer_login('01285286828')
    params = {
      address_type: 'manual_input',
      city: 'Hồ Chí Minh',
      district: 'Quận 8',
      latitude: '10.747580',
      longitude: '106.688994',
      mode_of_payment: 'okiela_24_7',
      name: 'Hiep Dinh',
      okiela_24_7_nationwide_flag: '2',
      order_id: '28037950',
      phone: '01285286828',
      shipping_fee_amount: '20000',
      skip_verify_exist_phone: '1',
      street: '147 Dương Bá Trạc',
      ward: 'Phường 1'
    }

    resp = put('orders/buyer/update_mode_of_payment', params, api_token)
    resp.status_200?
  end

  # rake -f rake_tests/orders.rake orders:driver_pickup_order MODE=dev DISPLAY_TIMES=1 CODE=MD53503082 PRESS_KEY_CONTINUE=true
  task driver_pickup_order: :environment do |t|
    ENV['CODE'] ||= load_order_code
    starting(t)
    order = Backend::App::Orders.by_parameters(code: ENV['CODE'])
    delay_time = 5
    press_key_continue = ENV['PRESS_KEY_CONTINUE'].boolean_true?

    run('orders:display_client_order_statistics')
    delay(delay_time, description: "Waiting for progress to next step \"ĐANG ĐI GIAO\"", press_key_continue: press_key_continue)

    dashboard_logistic_login!
    resp = post('logistics/manager_change_oll_order_type', { 
      order_id: order.id, 
      new_okiela_24_7_nationwide_flag: 2
    }, api_token)

    puts "\n\n"
    run('orders:logistic_order_work_flow')
    details_msg('INFO', "After driver pickup")
    run('orders:display_client_order_statistics')
    delay(delay_time, description: "Waiting for progress to next step \"CẦN XỬ LÝ\"", press_key_continue: press_key_continue)

    order = Backend::App::Orders.by_id(order.id, true)
    pickup_driver_id = order.pickup_driver
    deliver_driver_id = order.deliver_driver

    # logistic_login('0848760540', '123456')
    # details_msg('INFO', "Driver picking up order #{order.code}")
    # resp = put('logistics/staff_confirm_keep_order', {order_id: order.id}, api_token)
    # resp.status_200_or_201?
    
    dashboard_logistic_login!
    details_msg('INFO', "\n\nReturn to OkieLa Giao")
    resp = put('logistics/manager_mark_pending_deliver_order', {order_id: order.id}, api_token)
    resp.status_200_or_201?
    run('orders:display_client_order_statistics')

    case ENV['CASE']
    when 'completed', 'cancel2'
      details_msg('INFO', "Follow GIAO THÀNH CÔNG")
      delay(delay_time, description: "Waiting for progress to next step \"GIAO LẠI\"", press_key_continue: press_key_continue)

      resp = put('external_clients/delivery/orders/feedback_order', {
        order_id: order.id,
        feedback_status: 'deliver_again',
        force_cancel: true,
        force_send_sms: false
      }, api_token)
      run('orders:display_client_order_statistics')
      delay(delay_time, description: "Waiting for progress to next step \"Pickup driver delivered\"", press_key_continue: press_key_continue)

      logistic_login(Backend::App::LogisticUsers.by_id(pickup_driver_id).phone, '123456')
      details_msg('INFO', "Driver delivered order ##{order.code} to dropoff")
      resp = put('logistics/staff_confirm_delivered_order', {order_id: order.id}, api_token)
      resp.status_200_or_201?

      if ENV['CASE'] != 'cancel2'
        delay(delay_time, description: "Waiting for progress \"Thanh toán\" to next step \"GIAO THÀNH CÔNG\"", press_key_continue: press_key_continue)

        dashboard_logistic_login!
        resp = put('logistics/payoo_confirm_payment', {order_id: order.id, auth_key: '3VlXnwbIxJkzJKKEr50hCw=='}, api_token)
        resp.status_201?
      else
        delay(1, description: "FOLLOW HỦY 2", press_key_continue: true)
        dashboard_logistic_login!

        delay(1, description: "Dashboard mark pending delivery", press_key_continue: press_key_continue)
        resp = put('logistics/manager_mark_pending_deliver_order', {order_id: order.id}, api_token)
        resp.status_200_or_201?
        run('orders:display_client_order_statistics')

        delay(1, description: "Client choose option \"Giao lại cho OkieLa Giao\"", press_key_continue: press_key_continue)
        resp = put('external_clients/delivery/orders/feedback_order', {
          order_id: order.id,
          feedback_status: 'return_package',
          force_cancel: true,
          force_send_sms: false
        }, api_token)
        resp.status_200_or_201?

        dashboard_logistic_login!
        details_msg('INFO', "Dash board assign cho driver")
        resp = put('logistics/logistic_assign_driver', {
          deliver_driver_id: pickup_driver_id,
          order_id: order.id,
          pickup_driver_id: pickup_driver_id
        }, api_token)
        resp.status_200_or_201?

        logistic_login(Backend::App::LogisticUsers.by_id(pickup_driver_id).phone, '123456')
        details_msg('INFO', "Driver picking up order #{order.code}")
        resp = put('logistics/staff_confirm_keep_order', {order_id: order.id}, api_token)
        resp.status_200_or_201?
      end
    when 'cancel1'
      details_msg('INFO', "Follow HỦY 1")
      delay(delay_time, description: "Waiting for progress to next step \"HỦY 1 - \"", press_key_continue: press_key_continue)
      resp = put('external_clients/delivery/orders/feedback_order', {
        order_id: order.id,
        feedback_status: 'return_package',
        force_cancel: true,
        force_send_sms: false
      }, api_token)
      # Backend::App::Users.by_id(583647).get_ex_client_financial_info(force_reload: true)
    end
  end

  # rake -f rake_tests/orders.rake orders:display_client_order_statistics MODE=dev DISPLAY_TIMES=1 CODE=MD53503082
  task display_client_order_statistics: :environment do |t|
    order = Backend::App::Orders.by_parameters(code: ENV['CODE'])
    client = Backend::App::Users.by_id(order.client_id)
    client_login(client.phone, '123456')
    change_to_dev_server!
    (ENV["DISPLAY_TIMES"] || 1).to_i.times do |i|
      resp = get('external_clients/delivery/financial_report', {}, api_token)
      details_msg("INFO ##{i}", '')
      financial_report = resp['financial_report']
      data = {
        'CHỜ TỚI LẤY' => financial_report['pending_pickup_num_of_orders'],
        'ĐANG ĐI GIAO' => financial_report['delivering_num_of_orders'],
        'GIAO THÀNH CÔNG' => financial_report['delivered_num_of_orders'],
        'HỦY' => financial_report['cancelled_num_of_orders'],
        'CẦN XỬ LÝ' => financial_report['pending_deliver_num_of_orders'],
      }
      disply_tables(data: data)
      sleep(1)
    end
  end

  # rake -f rake_tests/orders.rake orders:restore_order_back_to_before_pickup_step MODE=dev DISPLAY_TIMES=1 CODE=MD14923082
  task restore_order_back_to_before_pickup_step: :environment do |t|
    starting(t)

    ENV['DISPLAY_TIMES'] = '1'
    run('orders:order_details')
    run('orders:display_client_order_statistics')

    ENV['MODE'] = 'dev'
    irb_cmd([
      "@order = Backend::App::Orders.by_parameters(code: 'MD88823082')",
      "@order.logistic_order_status = 'new'",
      "@order.keeping_role = nil",
      "@order.is_packed = 0",
      "@order.processing_status = 'active_processing'",
      "@order.read_status = 'unread'",
      "@order.check_status = 'unconfirmed'",
      "@order.save"
    ])

    run('orders:order_details')
    run('orders:display_client_order_statistics')
    pass(t)
  end

  task order_details: :environment do |t|
    ENV['ID'] = Backend::App::Orders.by_parameters(code: ENV['CODE']).id.to_s if ENV['ID'].blank? && ENV['CODE'].present?
    order = Backend::App::Orders.by_id(ENV['ID'], true)

    details_msg('INFO', "Order logistic_order_status: #{order.logistic_order_status}")
    # details_msg('INFO', "Order should_send_notify_client_order_placed_at_dropoff?: #{order.should_send_notify_client_order_placed_at_dropoff?}")
    details_msg('INFO', "Order logistic_drop_off_confirmed?: #{order.logistic_drop_off_confirmed?}")
    details_msg('INFO', "Order logistic_dropoff_status.nil?: #{order.logistic_dropoff_status.nil?}")
    details_msg('INFO', "Order is_oll_dropoff_deliver?: #{order.is_oll_dropoff_deliver?}")
    details_msg('INFO', "Order is_client_purchase?: #{order.is_client_purchase?}\n")
    details_msg('INFO', "Order final_price #{order.final_price}")
    details_msg('INFO', "Order final_price_after_tax #{order.final_price_after_tax}")
    details_msg('INFO', "Order final_purchase_price #{order.final_purchase_price}\n")
    details_msg('INFO', "Order final_dropoff_is_contractor? #{order.final_dropoff_is_contractor?}\n")
  end

  # rake -f rake_tests/orders.rake orders:set_order_contractor VALUE=true CODE=MD44323082 MODE=dev
  task set_order_contractor: :environment do |t|
    run('orders:order_details')
    address_id = Backend::App::Orders.by_parameters(code: ENV['CODE']).final_dropoff_obj.address.id
    address    = Backend::App::Addresses.by_id(address_id)
    address.is_contractor_role = ENV['VALUE'].boolean_true?
    address.save
    run('orders:order_details')
  end
  
  task dropoff_location_info: :environment do |t|
    dropoff = Backend::App::LogisticDropoffLocations.by_id(ENV['ID'])
    details_msg('INFO', "Dropoff is_accessible?: #{dropoff.address.is_accessible?}")
    details_msg('INFO', "Dropoff is_contractor_role?: #{dropoff.address.is_contractor_role?}")
    details_msg('INFO', "Dropoff is_suspended?: #{dropoff.address.is_suspended?}")
    details_msg('INFO', "Dropoff is_on_vacation?: #{dropoff.address.is_on_vacation?}")
    details_msg('INFO', "Dropoff is_hidden?: #{dropoff.address.is_hidden?}")
  end 
end

