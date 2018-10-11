require_relative 'environment.rb'

START_DATE = 30.days_ago.unix_time
END_DATE = Time.now.unix_time

@order_codes_processing = []
@order_codes_completed = []

namespace :agents do
  task all: :environment do |t|
    starting(t)
    %w[01010101017 01248760542 01234567890 0898151235].each do |phone_number|
      agent_login(phone_number, '123456')
      details_msg('Login agent user', phone_number)
      run('agents:orders_commission_tabs_correct')
    end
    pass(t)
  end

  task sample: :environment do |t|
    # binding.pry
    # @user = get_logistic_user_by_phone(ENV['AGENT_PHONE'])
    # @order = Backend::App::Orders.by_id(544255)
    # order_status_valid!(resp, %w[completed])
    # logistic_dropoff_status_valid!(resp, %w[commissions_paid]) # Special case
  end

  task orders_commission_tabs_correct: :environment do |t|
    starting(t)
    run('agents:orders_commission_processing_all', true)
    run('agents:orders_commission_completed_all', true)

    details_msg('DEBUG', "Tab Processing has #{@order_codes_processing.count} Orders")
    details_msg('DEBUG', "Tab Completed has #{@order_codes_completed.count} Orders")

    @completed_not_included_in_processing = @order_codes_processing.shuffle_contain(@order_codes_completed)
    @completed_included_in_processing = @completed_not_included_in_processing.shuffle_contain(@order_codes_completed)
    if @completed_included_in_processing.empty?
      pass(t)
    else
      failure(t)
      details_msg('@completed_not_included_in_processing', @completed_not_included_in_processing)
      details_msg('@completed_included_in_processing', "#{@completed_included_in_processing} - Size: #{@completed_included_in_processing.count}")
      info_msg("\nDETAILS:")
      details_msg('@orders completed:', @order_codes_completed)
      details_msg('@order_codes_processing:', @order_codes_processing)
    end
  end

  task orders_commission_completed_all: :environment do |t|
    starting(t)
    results = { count: 0, codes: [] }

    resp = get_agent_orders(START_DATE, END_DATE, 'completed', 'agents_all', 0, 100)
    @order_codes_completed = resp['orders']['items'].map { |item| item['code'] }.uniq
    # success_msg("Orders #{@order_codes_processing.count} when processing and agents_all")

    resp = get_agent_orders(START_DATE, END_DATE, 'completed', 'agents_agent_order', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items'].count} when completed and agents_agent_order")

    resp = get_agent_orders(START_DATE, END_DATE, 'completed', 'agents_dropoff_order', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items'].count} when completed and agents_dropoff_order")

    if @order_codes_completed.shuffle_contain_each_other?(results[:codes])
      pass(t)
    else
      tabs_not_include_all = @order_codes_completed.shuffle_contain(results[:codes])
      all_not_include_tabs = results[:codes].shuffle_contain(@order_codes_completed)
      txt = []
      txt << "\ntabs_not_include_all: #{tabs_not_include_all}" if tabs_not_include_all.any?
      txt << "\nall_not_include_tabs: #{all_not_include_tabs}" if all_not_include_tabs.any?
      failure(t, txt.join(' - - - '))
    end
  end

  task orders_commission_processing_all: :environment do |t|
    starting(t)
    results = { count: 0, codes: [] }
    
    resp = get_agent_orders(START_DATE, END_DATE, 'processing', 'agents_all', 0, 100)
    @order_codes_processing = resp['orders']['items'].map { |item| item['code'] }.uniq
    # success_msg("Orders #{@order_codes_processing.count} when processing and agents_all")

    resp = get_agent_orders(START_DATE, END_DATE, 'processing', 'agents_agent_order', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items'].count} when processing and agents_agent_order")

    resp = get_agent_orders(START_DATE, END_DATE, 'processing', 'agents_dropoff_confirmed', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items'].count} when processing and agents_dropoff_confirmed")

    resp = get_agent_orders(START_DATE, END_DATE, 'processing', 'agents_cancelled', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items']} when processing and agents_cancelled")

    resp = get_agent_orders(START_DATE, END_DATE, 'completed', 'agents_delivered', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items'].count} when completed and agents_delivered")

    resp = get_agent_orders(START_DATE, END_DATE, 'completed', 'agents_money_received', 0, 100)
    results[:codes].concat(resp['orders']['items'].map { |item| item['code'] })
    # results[:count] += resp['orders']['items'].count
    # success_msg("Orders #{resp['orders']['items'].count} when completed and agents_money_received")

    if @order_codes_processing.shuffle_contain_each_other?(results[:codes])
      pass(t)
    else
      tabs_not_include_all = @order_codes_processing.shuffle_contain(results[:codes])
      all_not_include_tabs = results[:codes].shuffle_contain(@order_codes_processing)
      txt = []
      txt << "\ntabs_not_include_all: #{tabs_not_include_all}" if tabs_not_include_all.any?
      txt << "\nall_not_include_tabs: #{all_not_include_tabs}" if all_not_include_tabs.any?
      failure(t, txt.join(' - - - '))
    end
  end

  task orders_commission_processing: :environment do |t|
    starting(t)
    resp = get_agent_orders(START_DATE, END_DATE, 'processing', 'agents_dropoff_order', 0, 15)
    resp.status_200?
    order_status_valid!(resp, %w[processing pending_canceled])
    pass(t)
  end

  task orders_commission_agents_money_received: :environment do |t|
    starting(t)
    resp = get_agent_orders(START_DATE, END_DATE, 'processing', 'agents_money_received', 0, 15)
    resp.status_200?
    order_status_valid!(resp, %w[processing pending_canceled])
    logistic_order_status_valid!(resp, %w[money_received])
    pass(t)
  end

  def get_agent_orders(start_date, end_date, order_status_type = '', order_type = '', offset = 0, limit = 15)
    resp = {}
    print_memory_usage do
      print_time_spent do
        # success_msg "Method get_agent_orders: start_date: #{start_date} - end_date: #{end_date} - order_status_type: #{order_status_type} - order_type: #{order_type}"
        resp =
          get(
            'agents/orders',
            {
              start_date: start_date,
              end_date: end_date,
              order_status_type: order_status_type,
              order_type: order_type,
              offset: offset,
              limit: limit
            },
            api_token
          )
      end
    end
    resp
  end

  def order_status_valid!(resp, status_expected)
    fetch_items(resp).all?{ |order| status_expected.include?(order['order_status']) }
  end
  
  def logistic_dropoff_status_valid!(resp, status_expected)
    fetch_items(resp).all?{ |order| status_expected.include?(order['logistic_dropoff_status']) }
  end
  
  def logistic_order_status_valid!(resp, status_expected)
    fetch_items(resp).all? { |order| status_expected.include?(order['logistic_order_status']) }
  end

  def fetch_item(resp)
    items = resp['orders']['items'] rescue []
    raise 'Item was empty' if items.empty?
  end
end
