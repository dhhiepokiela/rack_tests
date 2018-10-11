require_relative 'environment.rb'

namespace :exports do
  task admin_dashboard_login: :environment do |t|
    resp = dashboard_logistic_login!
    resp.status_200?
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
        "client_order_detail", "client_is_fragile", "client_check_before_accept", "client_buyer_pay_delivery_fee"
      ]',
      creator: [],
      oll_types: %w[okiela_24_7_hcm],
      order_type: 'dashboard_general',
      start_date: 2.days_ago.strftime('%s'),
      end_date: 0.days_from_now.strftime('%s')
    }

    resp = post('logistics/export_order', export_params, api_token)
    resp.status_200?
    success_msg "Test file exported here: ~/WorkSpaces/Okiela_Backend/temp/file/excel/#{resp['filename']}"
  end
end



