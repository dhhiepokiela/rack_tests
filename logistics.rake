require_relative 'environment.rb'

namespace :logistics do
  task all: :environment do |t|
    starting(t)
    run('logistics:delivery_import_order')
    run('logistics:multi_send_to_nationwide')
    pass(t)
  end
  
  task admin_dashboard_login: :environment do |t|
    resp = dashboard_logistic_login!
    resp.status_200?
  end

  task manager_update_package_weight: :environment do |t|
    starting(t)
    run('logistics:admin_dashboard_login', true)

    details_msg("\nSTEP", 'VALIDATION CHECKING ...')
    # 'Danh sách đơn hàng không được phép để trống.'
    # 'Danh sách đơn hàng không hợp lệ'
    # 'Email không được phép để trống khi có nhiều hơn một đơn hàng'
  
    fields = %w[entity_id code delivery_original_price okiela_24_7_delivery_fee okiela_24_7_shipping_fee final_order_discount final_price final_price_after_tax]
    codes = %w[MD20031082 MD200310822]
    # codes.concat %w[MD734385 MD044385 MD654385 MD954385 MD264385 MD564385 MD864385 MD374385 MD674385 MD974385 MD284385 MD094385 MD394385 MD694385 MD994385 MD205385 MD505385 MD425385 MD725385 MD035385]

    codes.concat %w[MD92821082]


    old_orders = load_order_fee(fields, codes)
    old_weights = load_order_weight(codes)
    display_order_fee(fields, old_orders, old_weights)
    list_orders =
      codes.map do |code|
        "{\"code\": \"#{code}\", \"weight\": \"#{old_weights[code].to_i + 100}\"}"
      end.join(',')

    resp = post('logistics/manager_update_package_weight', { email: 'hoanghiepitvnn@gmail.com', list_orders: "[#{list_orders}]" }, api_token)
    resp.status_200?

    details_msg("\n\nINFO", 'Execute rake job_queues:process')
    run_sys_cmd(['rake job_queues:process'])

    pass(t)
  end

  task update_dropoff_owner: :environment do |t|
    starting(t)

    run('logistics:admin_dashboard_login', true)

    details_msg("\nAction", 'Sending request to server update_dropoff_owner')
    phone_number = "078528#{ "%02d" % rand(1000..9999) }"
    resp = put('logistics/update_dropoff_owner', { dropoff_location_id: '28013536', dropoff_owner_id: '28013549', phone: phone_number }, api_token)
    resp.status_200?
    dropoff_owner = Backend::App::LogisticUsers.by_id('28013549', true)
    resp.eq?(dropoff_owner.phone, phone_number)
    pass(t)
  end 

  task load_orders_by_driver: :environment do |t|
    starting(t)

    [1, 2, 3, 5].each do |id|
      phone = "089815710#{id}"
      driver_id = Backend::App::LogisticUsers.by_parameters(phone: phone, limit: 1).id rescue nil
      display_orders_by_driver(driver_id) if driver_id.present?
    end
    pass(t)

    # db = SequelDbConnection.get_connector
    # user = nil
    # db.transaction do
    #   user = Backend::App::Users.by_parameters(phone: '0785286828')
    #   details_msg("INFO", "Name 1: #{Backend::App::Users.by_id(user.id, true).forename}")
    #   user.forename = 'Test'
    #   user.save
    #   ddd
    #   details_msg("INFO", "Name 2: #{Backend::App::Users.by_id(user.id, true).forename}")
    #   raise(Sequel::Rollback)
    # end
    # details_msg("INFO", "Name 3: #{Backend::App::Users.by_id(user.id, true).forename}")
    # pass(t)
  end

  task load_orders: :environment do |t|
    starting(t)
    limit = 500
    run('logistics:admin_dashboard_login', true)

    details_msg("\nAction", 'Sending request to server with order_type is dashboard_nationwide_sent')
    resp = get('logistics/orders', { order_type: 'dashboard_nationwide_sent', view_type: 'dashboard_general_info', limit: limit }, api_token)
    resp.status_200?
    logistic_order_status_match?(resp, [1], %w[nationwide_sent])
    success_msg("Test case dashboard_nationwide_sent was PASSED")

    details_msg("\nAction", 'Sending request to server with order_type is dashboard_buses_sent')
    resp = get('logistics/orders', { order_type: 'dashboard_buses_sent', view_type: 'dashboard_general_info', limit: limit }, api_token)
    resp.status_200?
    logistic_order_status_match?(resp, [2, 3], %w[buses_sent])
    success_msg("Test case dashboard_buses_sent was PASSED")

    details_msg("\nAction", 'Sending request to server with order_type is dashboard_assigned')
    resp = get('logistics/orders', { order_type: 'dashboard_assigned', view_type: 'dashboard_general_info', limit: limit }, api_token)
    resp.status_200?
    logistic_order_status_match?(resp, [], Backend::App::Order::ASSIGNED_LOGISTIC_ORDER_STATUSES)
    success_msg("Test case dashboard_assigned was PASSED")

    details_msg("\nAction", 'Sending request to server with order_type is pending_assign_not_payoo')
    resp = get('logistics/orders', { order_type: 'pending_assign_not_payoo', view_type: 'dashboard_general_info', limit: limit }, api_token)
    resp.status_200?
    logistic_order_status_match?(resp, [], ['new'])
    success_msg("Test case pending_assign_not_payoo was PASSED")

    pass(t)
  end

  task manager_switch_pickup_driver: :environment do |t|
    starting(t)
    run('logistics:admin_dashboard_login', true)

    driver_ids = [384702, 391455]
    params = {
      current_pickup_driver_id: driver_ids[0],
      new_pickup_driver_id: driver_ids[1],
      email: 'hoanghiepitvnn@gmail.com',
      shop_ids: '1,2,3',
      district_ids: '1,2,3'
    }

    details_msg('INFO', 'Run test case validation full district_ids and shop_ids')
    resp = post('logistics/manager_switch_pickup_driver', params, api_token)
    resp.status_403?

    details_msg('INFO', 'Run test case validation missing district_ids and shop_ids')
    resp = post('logistics/manager_switch_pickup_driver', params.except(:shop_ids, :district_ids), api_token)
    resp.status_403?

    reset_order_to_driver(
      params[:current_pickup_driver_id],
      %w[
        MD892583 MD225583 MD032683 MD831983 MD942093 MD921193 
        MD431193 MD137393 MD369393 MD179393 MD541024 MD612344
        MD780824 MD992144 MD04029972 MD64029972 MD874355
      ]
    )

    manager_switch_pickup_driver(shop_ids: '305666,381477') # Warehouse ID: 382230 - Shop ID: 381477 AND Warehouse ID: 305900 - Shop ID: 305666
    manager_switch_pickup_driver(district_ids: '17,37') # Huyện Ba Vì AND quận 8

    pass(t)
  end

  def manager_switch_pickup_driver(shop_ids: nil, district_ids: nil)
      districts = Backend::App::MiscServices::LocationService.new.get_all_districts.inject({}){|r, e| r.merge(e["district_id"] => e["name"])}
      driver_ids = [384702, 391455]
      base_params = {
        current_pickup_driver_id: driver_ids[0],
        new_pickup_driver_id: driver_ids[1],
        email: 'hoanghiepitvnn@gmail.com'
      }

      base_params.merge!(shop_ids: shop_ids) if shop_ids
      base_params.merge!(district_ids: district_ids) if district_ids

      details_msg("INFO", 'Switch PickupDriver Order parameter')
      info_msg(base_params.to_s)

      details_msg("INFO", 'Show current order on current driver and new driver')
      driver_ids.each { |driver_id| display_orders_by_driver(driver_id) }

      details_msg("ACTION", 'Backing up orders for current driver')
      current_driver_orders_backups = get_orders_by_driver(base_params[:current_pickup_driver_id])
      new_driver_orders_backups = get_orders_by_driver(base_params[:new_pickup_driver_id])
      details_msg("ACTION", "Store current driver orders #{current_driver_orders_backups.count} orders")
      details_msg("ACTION", "Store new driver orders #{new_driver_orders_backups.count} orders")

      resp = post('logistics/manager_switch_pickup_driver', base_params, api_token)
      resp.status_200?
      delay(5)
      details_msg("\n\nINFO", 'Execute rake job_queues:process')
      run_sys_cmd(['rake job_queues:process'])
      details_msg("\n\nINFO", 'Show current order on current driver and new driver')
      driver_ids.each { |driver_id| display_orders_by_driver(driver_id) }
      delay(5)

      current_driver_orders = get_orders_by_driver(base_params[:current_pickup_driver_id])
      new_driver_orders = get_orders_by_driver(base_params[:new_pickup_driver_id])
      details_msg("ACTION", "Store current driver orders #{current_driver_orders.count} orders")
      details_msg("ACTION", "Store new driver orders #{new_driver_orders.count} orders")

      details_msg("\n\nINFO", "Checking new driver's orders (ID: #{base_params[:new_pickup_driver_id]})...")
      resp.eq?(current_driver_orders_backups.count - current_driver_orders.count, new_driver_orders.count - new_driver_orders_backups.count)

      details_msg("\n\nINFO", "Checking old driver's orders (ID: #{base_params[:current_pickup_driver_id]})...")
      current_driver_orders.each do |order|
        if shop_ids
          details_msg("INFO", " - - Verify order #{order.code} base on shop_ids #{shop_ids}...")
          resp.not_include?(shop_ids.split(',').map(&:to_i), order.shop_id)
        end

        if district_ids
          details_msg("INFO", " - - Verify order #{order.code} base on district_ids #{district_ids}...")
          district_names = district_ids.split(',').map{|e| districts[e.to_i] }
          district_name = order.shop_dropoff_obj.address.district rescue nil
          resp.not_include?(district_names, district_name)
        end
      end

      details_msg("ACTION", 'Restoring orders for current driver')
      reset_order_to_driver(base_params[:current_pickup_driver_id], current_driver_orders_backups.map(&:code))
      resp.eq?(current_driver_orders_backups.map(&:id), get_orders_by_driver(base_params[:current_pickup_driver_id]).map(&:id))

      details_msg("INFO", 'Show current order on current driver and new driver')
      driver_ids.each { |driver_id| display_orders_by_driver(driver_id) }
  end

  task multi_send_to_nationwide: :environment do |t|
    starting(t)
    run('logistics:admin_dashboard_login', true)
    run('logistics:backup_order_status')
    # run('logistics:load_orders')
    multi_send_to_nationwide
    # run('logistics:load_orders')
    run('logistics:restore_logistic_order_status')
    # run('logistics:load_orders')
    pass(t)
  end

  task delivery_import_order: :environment do |t|
    starting(t)
    run('logistics:admin_dashboard_login', true)
    resp = post('logistics/delivery/import_order', {
      order_data: sample_data_for_import_orders,
      file_name: 'test.txt',
      client_id: 583647,
      email: 'hoanghiepitvnn@gmail.com'
    }, api_token)
    
    resp.status_200?
    resp.message_eq?('Đã cập nhật thành công !')
    delay(5)
    details_msg('Action', 'Calling task \'rake job_queues:process\' ...')
    # run_sys_cmd(['rake job_queues:process'])
    pass(t)
  end

  task backup_order_status: :environment do |t|
    starting(t)
    preparing_order_codes
    details_msg('Action', 'Database is backing up ...')
    @backup_order_status = fetch_logistic_order_status(@all_orders)
    pass(t)
  end

  task restore_logistic_order_status: :environment do |t|
    starting(t)
    details_msg("\nAction", 'Database is restoring ...')
    @after_restore = restore_logistic_order_status(@backup_order_status)
    delay(5)
    sync_es
    get('').eq?(@backup_order_status, @after_restore)
    pass(t)
  end

  def multi_send_to_nationwide
    order_code_list = []
    @all_orders.each do |code|
      order_code_list << {
        code: code,
        date: rand(1..10).days_ago.strftime('%Y-%m-%d %H:%M')
      }
    end

    params = {
      email: 'hoanghiepitvnn@gmail.com',
      order_code_list: order_code_list.to_json
    }

    details_msg('Action', 'Sending request to server ...')
    resp = put('logistics/orders/multi_send_to_nationwide', params, api_token)
    resp.status_200?
    delay(5)
    details_msg('Action', 'Calling task \'rake job_queues:process\' ...')
    # run_sys_cmd(['rake job_queues:process'])
    delay(5)
    # sync_es

    # details_msg('Action', 'Process and checking to ensure data valid ...')
    # JSON.parse(params[:order_code_list], symbolize_names: true).each do |item|
    #   order_id = Backend::App::Orders.by_parameters(code: item[:code], limit: 1).try(:id)
    #   unless order_id
    #     error_msg("Order #{item[:code]} was not found!")
    #     next
    #   end
    #   order = Backend::App::Orders.by_id(order_id, true)
    #   is_hcm_order = @hcm_orders.include?(item[:code])
    #   is_nationwide_order = @nationwide_orders.include?(item[:code])
    #   is_buses_order = @buses_orders.include?(item[:code])
    #   logistic_order_status =
    #     case true
    #     when is_nationwide_order
    #       'nationwide_sent'
    #     when is_buses_order
    #       'buses_sent'
    #     when is_hcm_order
    #       %w[nationwide_sent buses_sent]
    #     end

    #   begin
    #     if is_hcm_order
    #       resp.not_include?(logistic_order_status, order.logistic_order_status)
    #     else
    #       resp.eq?(order.logistic_order_status, logistic_order_status)
    #       resp.eq?(order.nationwide_sent_date.strftime('%Y-%m-%d %H:%M'), item[:date])
    #     end
    #     success_msg_inline('.')
    #   rescue Exception => e
    #     error_msg("\nOrder #{item[:code]} => #{e}")
    #     binding.pry
    #   end
    # end

    puts ''
  end

  def preparing_order_codes
    # @hcm_orders = %w[MD275275 MD391275 MD131275 MD791175 MD951175]
    # @nationwide_orders = %w[MD936995 MD536995 MD522995 MD222995 MD912995]
    # @buses_orders = %w[MD99149972 MD69149972 MD09149972 MD45149972 MD15149972 MS00139972 MS89039972 MS49039972 MS88039972 MS38039972]
    load_random_order
    @all_orders = [@hcm_orders, @nationwide_orders, @buses_orders].flatten
  end

  def fetch_logistic_order_status(order_codes)
    sql = <<-SQL
      SELECT code, logistic_order_status
      FROM res_order
      WHERE code IN (#{order_codes.map{|code| "'#{code}'"}.join(',')})
    SQL
    execute_sql(sql).to_a
  end

  def restore_logistic_order_status(orders)
    orders.each do |order|
      sql = <<-SQL
        update res_order
        set es_synced = 0, logistic_order_status = '#{order[:logistic_order_status]}'
        WHERE code = '#{order[:code]}'
      SQL
      execute_sql(sql)
    end
    fetch_logistic_order_status(orders.map { |order| order[:code] })
  end

  def logistic_order_status_match?(resp, flags = [], statuses = [])
    items = resp['orders']['items']
    details_msg('INFO', "Got #{items.count} with flags is #{flags.join(', ')} and status is #{statuses.join(', ')}")
    items.each do |item|
      if flags.any?
        if item['okiela_24_7_nationwide_flag'].present?
          begin
            resp.include?(flags, item['okiela_24_7_nationwide_flag'])
          rescue Exception => e
            error_msg("Value Got #{item['okiela_24_7_nationwide_flag']} when check item #{item['id']} in #{flags}")
            check_and_delete_order_on_es(item['id'])
          end
        else
          error_msg("Value got nil when check item #{item['id']} in #{flags}")
        end
      end
      if statuses.any?
        if item['logistic_order_status'].present?
          begin
            resp.include?(statuses, item['logistic_order_status'])
          rescue Exception => e
            binding.pry
            error_msg("Value got #{item['logistic_order_status']} when check item #{item['id']} in #{statuses}")
            check_and_delete_order_on_es(item['id'])
          end
        else
          error_msg("Value got nil when check item #{item['id']} in #{statuses}")
        end
      end
    end
  end

  def load_random_order
    sql = <<-SQL
      select code
      from res_order
      where
        okiela_24_7_nationwide_flag = 0 AND
        keeping_driver IS NOT NULL AND
        logistic_order_status IN ('delivery_driver', 'drop_off', 'final_van_helper', 'at_hub')
      ORDER BY entity_id desc
      limit 5 offset 0
    SQL

    @hcm_orders = execute_sql(sql).to_a.map{|e| e[:code]}

    sql = <<-SQL
      SELECT code
      FROM res_order
      WHERE
        keeping_driver IS NOT NULL AND
        okiela_24_7_nationwide_flag in (1) AND
        logistic_order_status IN ('delivery_driver', 'drop_off', 'final_van_helper', 'at_hub') AND
        logistic_order_status <> "nationwide_sent"
      ORDER BY entity_id desc
      limit 5 offset 10
    SQL

    @nationwide_orders = execute_sql(sql).to_a.map{|e| e[:code]}

    sql = <<-SQL
      SELECT code
      FROM res_order
      WHERE
        keeping_driver IS NOT NULL AND
        okiela_24_7_nationwide_flag in (2) AND
        logistic_order_status IN ('delivery_driver', 'drop_off', 'final_van_helper', 'at_hub') AND
        logistic_order_status <> "buses_sent"
      ORDER BY entity_id desc
      limit 3 offset 10
    SQL
    @buses_orders = execute_sql(sql).to_a.map{|e| e[:code]}

    sql = <<-SQL
      SELECT code
      FROM res_order
      WHERE
        keeping_driver IS NOT NULL AND
        okiela_24_7_nationwide_flag in (3) AND
        logistic_order_status IN ('delivery_driver', 'drop_off', 'final_van_helper', 'at_hub') AND
        logistic_order_status <> "buses_sent"
      ORDER BY entity_id desc
      limit 3 offset 10
    SQL
    @buses_orders.concat(execute_sql(sql).to_a.map{|e| e[:code]})

    sql = <<-SQL
      SELECT code
      FROM res_order
      WHERE
        keeping_driver IS NULL AND
        okiela_24_7_nationwide_flag in (3)
      ORDER BY entity_id desc
      limit 3 offset 10
    SQL
    @buses_orders.concat(execute_sql(sql).to_a.map{|e| e[:code]})
  end

  def sample_data_for_import_orders
    '[
      {
        "delivery_barcode": "98765432345678",
        "delivery_code": "CS1000001",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 1",
        "delivery_original_price": "0",
        "package_weight": "100",
        "purchaser_name": "Chau Test",
        "purchaser_phone": "0987654321",
        "purchaser_address": "123 Nguyen Thi Minh Khai",
        "purchaser_city": "Hồ Chí Minh",
        "purchaser_district": "Quận 1",
        "check_before_accept": "1",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "0",
        "delivery_method": "fast"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000002",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 2",
        "delivery_original_price": "50000",
        "package_weight": "101",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654322",
        "purchaser_address": "133 Ngo Gia Tu",
        "purchaser_city": "Bắc Kạn",
        "purchaser_district": "Huyện Ngân Sơn",
        "check_before_accept": "1",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000003",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 3",
        "delivery_original_price": "1000000",
        "package_weight": "500",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654323",
        "purchaser_address": "Nguyen Van Cu",
        "purchaser_city": "Hồ Chí Minh",
        "purchaser_district": "Quận 10",
        "check_before_accept": "1",
        "is_fragile": "0",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "fast"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000004",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 4",
        "delivery_original_price": "0",
        "package_weight": "501",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654324",
        "purchaser_address": "222  CMT8",
        "purchaser_city": "Hồ Chí Minh",
        "purchaser_district": "Quận 3",
        "check_before_accept": "1",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "0",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000005",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 5",
        "delivery_original_price": "90000",
        "package_weight": "999",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654325",
        "purchaser_address": "Tran Hung Dao",
        "purchaser_city": "An Giang",
        "purchaser_district": "Thành Phố Long Xuyên",
        "check_before_accept": "1",
        "is_fragile": "0",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000006",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 6",
        "delivery_original_price": "1000000",
        "package_weight": "1000",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654326",
        "purchaser_address": "44 Ly Tu Trong",
        "purchaser_city": "Hồ Chí Minh",
        "purchaser_district": "Huyện Cần Giờ",
        "check_before_accept": "1",
        "is_fragile": "0",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000007",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 7",
        "delivery_original_price": "400000",
        "package_weight": "1001",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654327",
        "purchaser_address": "45 Ly Tu Trong",
        "purchaser_city": "Tiền Giang",
        "purchaser_district": "Huyện Cai Lậy",
        "check_before_accept": "0",
        "is_fragile": "0",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "fast"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000008",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 8",
        "delivery_original_price": "500000",
        "package_weight": "1499",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654328",
        "purchaser_address": "46 Ly Tu Trong",
        "purchaser_city": "Tây Ninh",
        "purchaser_district": "Huyện Gò Dầu",
        "check_before_accept": "1",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "fast"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000009",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 9",
        "delivery_original_price": "10000000",
        "package_weight": "1500",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654329",
        "purchaser_address": "47 Ly Tu Trong",
        "purchaser_city": "Hồ Chí Minh",
        "purchaser_district": "Quận 4",
        "check_before_accept": "1",
        "is_fragile": "0",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "fast"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000010",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 10",
        "delivery_original_price": "100000",
        "package_weight": "1501",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654330",
        "purchaser_address": "48 Ly Tu Trong",
        "purchaser_city": "Hồ Chí Minh",
        "purchaser_district": "Quận 5",
        "check_before_accept": "1",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "0",
        "delivery_method": "fast"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000011",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 11",
        "delivery_original_price": "99000",
        "package_weight": "1999",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654331",
        "purchaser_address": "133 Duong Ba Trac",
        "purchaser_city": "Bạc Liêu",
        "purchaser_district": "Huyện Hồng Dân",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000012",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 12",
        "delivery_original_price": "2000000",
        "package_weight": "2000",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654332",
        "purchaser_address": "134 Duong Ba Trac",
        "purchaser_city": "Bình Thuận",
        "purchaser_district": "Huyện Phú Quý",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000013",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 13",
        "delivery_original_price": "150000",
        "package_weight": "2001",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654333",
        "purchaser_address": "135 Duong Ba Trac",
        "purchaser_city": "Hà Nội",
        "purchaser_district": "Quận Hoàn Kiếm",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000014",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 14",
        "delivery_original_price": "150000",
        "package_weight": "2499",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654334",
        "purchaser_address": "136 Duong Ba Trac",
        "purchaser_city": "Hải Phòng",
        "purchaser_district": "Huyện Vĩnh Bảo",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000015",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 15",
        "delivery_original_price": "150000",
        "package_weight": "2500",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654335",
        "purchaser_address": "137 Duong Ba Trac",
        "purchaser_city": "Kontum",
        "purchaser_district": "Huyện Tu Mơ Rông",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000016",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 16",
        "delivery_original_price": "150000",
        "package_weight": "2501",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654336",
        "purchaser_address": "138 Duong Ba Trac",
        "purchaser_city": "Long An",
        "purchaser_district": "Huyện Châu Thành",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000017",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 17",
        "delivery_original_price": "150000",
        "package_weight": "3000",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654337",
        "purchaser_address": "139 Duong Ba Trac",
        "purchaser_city": "Long An",
        "purchaser_district": "Huyện Tân Thạnh",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000018",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 18",
        "delivery_original_price": "150000",
        "package_weight": "2000",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654338",
        "purchaser_address": "140 Duong Ba Trac",
        "purchaser_city": "Lâm Đồng",
        "purchaser_district": "Huyện Đơn Dương",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000019",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 19",
        "delivery_original_price": "150000",
        "package_weight": "2001",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654339",
        "purchaser_address": "141 Duong Ba Trac",
        "purchaser_city": "Ninh Bình",
        "purchaser_district": "Huyện Hoa Lư",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000020",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 20",
        "delivery_original_price": "150000",
        "package_weight": "3000",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654340",
        "purchaser_address": "142 Duong Ba Trac",
        "purchaser_city": "Phú Yên",
        "purchaser_district": "Thành Phố Tuy Hòa",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }, {
        "delivery_barcode": "",
        "delivery_code": "CS1000021",
        "shop_dropoff": "583659",
        "product_name": "Quan xa lon 21",
        "delivery_original_price": "150000",
        "package_weight": "1000",
        "purchaser_name": "Chau Nguyen",
        "purchaser_phone": "0987654341",
        "purchaser_address": "143 Duong Ba Trac",
        "purchaser_city": "Yên Bái",
        "purchaser_district": "Huyện Mù Cang Chải",
        "check_before_accept": "0",
        "is_fragile": "1",
        "buyer_pay_delivery_fee": "1",
        "delivery_method": "normal"
      }
    ]'
  end

  def get_orders_by_driver(driver_id)
    Backend::App::Orders.by_parameters(
      order_status: [ORDER_STATUS[:processing], ORDER_STATUS[:pending_canceled]],
      logistic_order_status: LOGISTIC_ORDER_STATUS[:seller_confirmed],
      logistic_pickup_driver: driver_id, limit: false
    )
  end

  def display_orders_by_driver(driver_id, phone = nil)
    orders = get_orders_by_driver(driver_id)
    details_msg("INFO", "Driver with phone #{phone} (#{driver_id}) has #{orders.count} orders")
    orders.each do |order|
      district_name = order.shop_dropoff_obj.address.district rescue nil
      details_msg("Details", "Order #{order.code} - District #{district_name} - Warehouse ID: #{order.shop_dropoff} - Shop ID: #{order.shop_id}")
    end
    info_msg("===\n")
  end

  def clean_orders
    sql = 
      <<-SQL
        SELECT entity_id
        FROM res_order
        WHERE logistic_order_status IN ("nationwide_sent","buses_sent")
      SQL

    orders = DatabasePool.get_connector.query(sql: sql).to_a.map{|e| e[:entity_id]}

    orders.map do |order_id|
      begin
        order = Backend::App::Orders.by_id(order_id.to_i, true)
        next unless order
        db = SequelDbConnection.get_connector
        db.transaction do
          order.reinventory_after_order_canceled
        end

        order.deactivate
        order.delete_order
        check_and_delete_order_on_es(order_id)
        sleep 3
      rescue
        puts order_id
      end
    end
  end

  def reset_order_to_driver(driver_id, orders)
    # current_driver_orders_backups.map(&:id).each do |code|
    #   order = Backend::App::Orders.by_id(code, true)
    #   order.pickup_driver = base_params[:current_pickup_driver_id]
    #   order.save
    # end

    sql =
      <<-SQL
        update res_order
        set es_synced = 0, 
            pickup_driver = #{driver_id}
        WHERE code IN (#{orders.inject([]){|a, e| a << ("'#{e}'")}.join(',')})
      SQL

    execute_sql(sql)
    sync_es
  end

  def display_order_fee(fields, orders, weights)
    orders.each do |order|
      puts "\n==========\n"
      puts [
        order.map{|k, v| "#{k}: #{v}"},
        "weight: #{weights[order[:code]]}"
      ].join("\n")
    end
  end

  def load_order_fee(fields, codes)
    sql =
      <<-SQL
        SELECT #{fields.join(',')}
        FROM res_order
        WHERE code IN (#{codes.inject([]){|a, e| a << ("'#{e}'")}.join(',')})
        ORDER BY entity_id
      SQL

    execute_sql(sql).to_a
  end

  def load_order_weight(codes)
    codes.inject({}) do |result, code|
      order = Backend::App::Orders.by_parameters(code: code, limit: 1) 
      return result if order.nil? || order.order_detail_collection.nil? || order.order_detail_collection.first.nil?
      result.merge(code => order.order_detail_collection.first.package_weight)
    end
  end
end
