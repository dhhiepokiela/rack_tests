require_relative 'environment.rb'

namespace :exports do
  task admin_dashboard_login: :environment do |t|
    resp = dashboard_logistic_login!
    resp.status_200?
  end

  task client_export_order: :environment do
    change_to_dev_server!
    # client_login('0391234510', '12345678')
    client_login('0327079597', '1234567')

    change_to_local_server!
    export_params = {
      # email: 'hiep.dinh@okiela.com',
      # client_order_status: '["delivering"]',
      # start_date: Time.parse('2019-10-18 23:59:59 +0700').to_i,
      # end_date: Time.parse('2019-10-26 23:59:59 +0700').to_i,
      client_order_status: '["delivered"]',
      email: 'hiep.dinh@okiela.com',
      end_date: '1575392399.999',
      start_date: '1574701200',
    }

    post('external_clients/delivery/export_order', export_params, api_token)
  end

  task export_order: :environment do |t|
    change_to_dev_server!
    run('exports:admin_dashboard_login', true)
    change_to_local_server!
    export_params = {
      columns_name: '[
        "stt", "okiela_24_7_nationwide_flag", "vendor_name", "initial_purchase_date", "code", "get_list_products",
        "final_price_after_tax", "coupon_value", "order_price_before_coupon", "okiela_24_7_shipping_fee", "final_price", "payoo_id",
        "payoo_id2", "okiela_commissions", "checkout_commissions", "original_checkout_commissions", "delivery_commissions",
        "additional_checkout_commissions", "commissions_paid_date", "shop_id", "shop_name", "shop_phone", "shop_address",
        "purchaser_name", "purchaser_phone", "purchaser_address", "dropoff_id", "dropoff_name", "dropoff_phone", "dropoff_address",
        "convert_logistic_order_status_for_dashboard", "reason_cancell", "pickup_date", "at_hub_date", "nationwide_sent_date",
        "drop_off_confirmed_date", "purchase_date", "pending_canceled_date", "keeping_driver_name", "pickup_driver_name",
        "delivery_driver_name", "agent_id", "agent_name", "agent_phone", "agent_address", "purchaser_city", "note",
        "okiela_24_7_delivery_fee", "purchaser_district", "money_paid_date", "client_delivery_code", "client_stt", "client_package_weight",
        "client_order_detail", "client_is_fragile", "client_check_before_accept", "client_buyer_pay_delivery_fee", "money_received_date",
        "delivery_method", "shop_district", "last_comments", "last_comment_date", "accountant_note", "note", "purchaser_region"
      ]',
      creator: [],
      oll_types: %w[okiela_24_7_hcm],
      order_type: 'dashboard_general',
      start_date: 1.days_ago.strftime('%s'),
      end_date: 0.days_from_now.strftime('%s')
    }

    resp = post('logistics/export_order', export_params, api_token)
    resp.status_200?
    success_msg "Test file exported here: ~/WorkSpaces/Okiela_Backend/temp/file/excel/#{resp['filename']}"
  end

  task export_finance_order: :environment do |t|
    change_to_dev_server!
    logistic_login('0933290685', '123456')
    # change_to_local_server!

    export_params = {
      columns_name: '[
        "stt", "okiela_24_7_nationwide_flag", "vendor_name", "initial_purchase_date", "code", "nationwide_tracking_code",
        "get_list_products", "final_price_after_tax", "coupon_value", "order_price_before_coupon", "okiela_24_7_shipping_fee",
        "okiela_24_7_delivery_fee", "final_price", "payoo_id", "payoo_id2", "delivery_method", "okiela_commissions",
        "checkout_commissions", "original_checkout_commissions", "delivery_commissions", "additional_checkout_commissions",
        "shipping_commissions", "commissions_paid_date", "money_paid_date", "shop_id", "shop_name", "shop_phone", "shop_address",
        "shop_district", "purchaser_name", "purchaser_phone", "purchaser_address", "purchaser_city", "purchaser_district", "dropoff_id",
        "dropoff_name", "dropoff_phone", "dropoff_address", "convert_logistic_order_status_for_dashboard", "reason_cancell",
        "pickup_date", "at_hub_date", "nationwide_sent_date", "drop_off_confirmed_date", "purchase_date", "pending_canceled_date",
        "money_received_date", "keeping_driver_name", "pickup_driver_name", "delivery_driver_name", "agent_id", "agent_name",
        "agent_phone", "agent_address", "client_delivery_code", "client_stt", "client_package_weight", "client_order_detail",
        "client_is_fragile", "client_check_before_accept", "client_buyer_pay_delivery_fee", "money_received_payment_code", "note"
      ]',
      end_date: 1554137990,
      order_type: 'dashboard_agent_payments',
      start_date: 1553446800
    }

    export_params = {
      columns_name: '["stt","okiela_24_7_nationwide_flag","vendor_name","initial_purchase_date","code","nationwide_tracking_code","get_list_products","final_price_after_tax","coupon_value","order_price_before_coupon","okiela_24_7_shipping_fee","okiela_24_7_delivery_fee","final_price","final_price_client_received","payoo_id","payoo_id2","delivery_method","okiela_commissions","checkout_commissions","original_checkout_commissions","delivery_commissions","additional_checkout_commissions","shipping_commissions","commissions_paid_date","money_paid_date","shop_id","shop_name","shop_phone","shop_address","shop_district","purchaser_name","purchaser_phone","purchaser_address","purchaser_city","purchaser_district","dropoff_id","dropoff_name","dropoff_phone","dropoff_address","convert_logistic_order_status_for_dashboard","reason_cancell","seller_confirmed_date","pickup_date","at_hub_date","nationwide_sent_date","nationwide_received_date","drop_off_confirmed_date","purchase_date","pending_canceled_date","money_received_date","keeping_driver_name","pickup_driver_name","delivery_driver_name","agent_id","agent_name","agent_phone","agent_address","client_delivery_code","client_stt","client_package_weight","client_order_detail","client_is_fragile","client_check_before_accept","client_buyer_pay_delivery_fee","money_received_payment_code","note","accountant_note"]',
      end_date: 1554224390,
      mode_of_payment: "[]",
      order_type: 'dashboard_agent_payments',
      start_date: 1551373200
    }

    resp = post('logistics/finance/export_order', export_params, api_token)

    # [
    #   # nil,
    #   [],
    #   # ['onepay_payment','bank_transfer', 'cash_pickup'],
    #   # ['onepay_payment'],
    #   # ['bank_transfer'],
    #   # ['cash_pickup'],
    #   # ['onepay_payment','bank_transfer'],
    #   # ['onepay_payment','cash_pickup'],
    #   # ['bank_transfer','cash_pickup']
    # ].each do |e|
    #   resp = post('logistics/finance/export_order', export_params.merge(mode_of_payment: e), api_token)
    #   # resp.status_200?
    #   success_msg "Test file exported here: ~/WorkSpaces/Okiela_Backend/temp/file/excel/#{resp['filename']}"
    # end
  end
end


