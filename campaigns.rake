require_relative 'environment.rb'

namespace :campaigns do
  task admin_dashboard_login: :environment do |t|
  end

  task agent_vendor_roles: :environment do |t|
    user_login('0785286828', '123456')
    # [
    #   nil,
    #   '',
    #   'dropoff_owner,agent',
    #   'dropoff_owner',
    #   'agent'
    # ]
    # ['agent'].each do |data_test|
    # endx

    change_to_dev_server!

    coupoun_value = 50000 #rand(10000..99000)
    coupon_params = {
      discount_type: 'money',
      code: "PHONE_REFILL_#{rand(1000..9999)}",
      value: coupoun_value,
      type: 'agent_vendor_promotion',
      initial_valid_date: '2018-12-05 08:00:00',
      expired_date: '2019-12-05 23:59:59',
      available_modes_of_payment: 'okiela_24_7,okiela_24_7_nationwide,okiela_24_7_drop_off_deliver,okiela_24_7_drop_off_pickup',
      min_price_of_order: '0',
      num_of_use: '3000',
      reuse_by_same_user: 'false'
    }

    
    coupon_resp = post('coupons', coupon_params, api_token)
    coupon_id = coupon_resp['coupon']['id']

    campaign_params = {
      title: "KHUYẾN MÃI HÔM NAY!\n#{coupoun_value}đ tiền nạp điện thoại MIỄN PHÍ! T1",
      button_title: "Nhấn vào để nhận #{coupoun_value}đ nạp điện thoại MIỄN PHÍ!",
      popup_title: "<font face=\"arial\">BẠN VỪA MỚI NHẬN ĐƯỢC <font color=\"#ff8400\">#{coupoun_value}đ</font> TIỀN KHUYẾN MÃI</font>",
      popup_content: "<font face=\"arial\">Khuyến mãi chỉ được sử dụng trong hôm nay thôi (#{Time.now.strftime('%d/%m/%Y')})</font>",
      popup_accept_text: "NẠP TIỀN ĐIỆN THOẠI",
      popup_deny_text: "BỎ QUA",
      type: "agent_vendor_promotion",
      start_date: "2018-12-05 08:00:00",
      end_date: "2019-12-05 23:59:59",
      service_type: "phone_refill",
      reload_cache: "true",
      coupon_id: coupon_id,
      # agent_vendor_roles: 'agent'
      agent_vendor_roles: 'dropoff_owner'
      # agent_vendor_roles: 'dropoff_owner,agent'
    }
    campaign_resp = post('campaigns', campaign_params, api_token)
    campaign_id = campaign_resp['campaign']['id']


    puts "Campaign #ID: #{campaign_id} - Coupon #ID: #{coupon_id} - Value: #{coupoun_value}"

    # ENV['MODE'] = 'dev'
    run_sys_cmd(['ruby ./tools/generate_vendor_promotional_campaign.rb'], ssh_servers: ['dev1'], sudo: false)

    # ENV['MODE'] = 'local'
    # change_to_local_server!
    
    confirm_use_params = {
      campaign_id: campaign_id,
      campaign_vendor_promotion_embedded: true,
      quantity: 1,
      service_provider: 'viettel',
      service_type: 'phone_card',
      tier_type: 'viettel_tier_3'
    }

    %w[0898157878 01010101017 0987777771 4910521112 4910521111 0834567891 0898159988 0898157878
      0987654321 01010101019 0898777777].each do |phone|
      agent_login(phone, '123456')
      res = post('agents/confirm_use_service', confirm_use_params, api_token)
    end
  end
end

