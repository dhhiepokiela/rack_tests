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

  task logistic_order_work_flow: :environment do |t|
    starting(t)

    ENV['ID'] = Backend::App::Orders.by_parameters(code: ENV['CODE']).id.to_s if ENV['ID'].blank? && ENV['CODE'].present?
    order = Backend::App::Orders.by_id(ENV['ID'], true)

    run('orders:order_details')

    current_user = dashboard_logistic_login!
    default_final_dropoff_id = 28012327
    default_pickup_driver_id = 582233
    default_deliver_driver_id = 582233

    resp = get("logistics/orders/#{order.id}/get_okiela_drop_off_address", {}, api_token)
    resp.status_200?
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
    resp.status_200?
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
    resp.status_200?
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
    resp.status_200?
    resp = put('logistics/dashboard_confirm_order', {
      order_id: order.id
    }, api_token)
    resp.status_200?
    details_msg('INFO', "Order is updated with: #{params_update_order.to_json}")

    details_msg('INFO', "Driver #{pickup_driver_text} picking up order #{order.code}")
    logistic_login(pickup_selected_driver['phone'], '123456')
    resp = put('logistics/staff_confirm_keep_order', {order_id: order.id }, api_token)
    resp.status_200?

    details_msg('INFO', "Driver #{pickup_driver_text} delivered order ##{order.code} to dropoff")
    resp = put('logistics/staff_confirm_delivered_order', {order_id: order.id}, api_token)
    resp.status_200?

    puts ""
    run('orders:order_details')
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

    # ['MD43422082', 'MD46422082', 'MD67422082', 'MD34422082', 'MD16422082'].each do |code|
    #   order = Backend::App::Orders.by_parameters(code: code)
    #   Backend::App::SmsHelper.notify_client_order_placed_dropoff_to_buyer(order)
    # end
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

