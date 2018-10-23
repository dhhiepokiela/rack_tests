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

  task create_success: :environment do |t|
    phone_number = "078528#{ "%02d" % rand(1000..9999) }"
    
    resp = create_client(phone_number)
    resp.status_200?
    
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

  task create_success_with_flag_change_password: :environment do |t|
    phone_number = "078528#{ "%02d" % rand(1000..9999) }"
    phone_number = '0386222225'    
    
    resp = create_client(phone_number)
    resp.status_200?

    force_reset_default_password_by_phone(phone_number) # 123456
    resp = client_login(phone_number, ENV['DEFAULT_PASSWORD'])
    resp.status_201?
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

  task simple_price_check: :environment do |t|
    change_to_dev_server!
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

  task price_check: :environment do |t|
    run('clients:login_success', true)
    @tolerance = 5 # minutes
    @test_validation = true
    change_to_dev_server!

    params = {
      package_weight: '2000',
      size: '10.6x5.1x30',
      shop_dropoff_id: '27993016',
      city_id: 50,
      district_id: 563
    }
    
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

    data_tests.each do |data_test|
      data_test.each do |test_case|
        success_msg "Processing test case: #{fect_province_and_district_name(test_case[:data])} - #{test_case[:data]} ..."
        success_msg "_ _ _ Normal expected: #{test_case[:expected][:normal]}"
        success_msg "_ _ _ Fast expected: #{test_case[:expected][:fast]}"
        resp = get('external_clients/delivery/price_check', params.merge(test_case[:data]), api_token)
        resp.status_200?
        resp['price_check'].each do |delivery_method|
          begin
            expected_deliver_time = Time.parse(delivery_method['expected_deliver_time'], '%Y-%m-%d %H:%M:%S %z')
            expected_deliver_max_time = Time.parse(delivery_method['expected_deliver_max_time'], '%Y-%m-%d %H:%M:%S %z')
            key = delivery_method['delivery_method'].to_sym
            delivery_method_name = key == :normal ? 'DỊCH VỤ BÌNH THƯỜNG' : 'DỊCH VỤ NHANH'
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
      email: "client_tester_#{suffix}@okiela.com",
      client_free_deliveries_number: 10,
      shop_name: "Shop ##{suffix}",
      shop_street: "#{suffix} Tan Ky Tan Quy",
      shop_ward: 'Phuong 6',
      shop_town: '',
      shop_district: 'Quận Tân Bình',
      shop_city: 'HCM'
    }

    post('external_clients', client_params, api_token)
  end

  def ensure_loged_in
    run('clients:manager_loged_in_success', true)
  end
end