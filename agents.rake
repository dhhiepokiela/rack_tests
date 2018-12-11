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

  # rake -f rake_tests/agents.rake agents:agent_balance_statistic AGENT_ID=28024436 TIMES=1
  task agent_balance_statistic: :environment do
    seconds = ENV['TIMES'].presence || '60'
    delay = ENV['DELAY'].presence || '5'
    seconds.to_i.times do |time|
      info_msg("\n= = = = = = = = = Statistic #{time + 1} time(s) at #{Time.now} = = = = = = = = =")
      agent_id = ENV['AGENT_ID']

      user_balances_columns = %i[
        entity_id balance_amount main_balance_amount credit_balance_amount extra_credit_balance_amount
      ]

      order_balances_columns = %i[
        entity_id credit_balance_for_order extra_credit_balance_for_order balance_after_order credit_balance_after_order
        extra_credit_balance_after_order purchase_date
      ]

      agent_balance_orders_columns = %i[
        entity_id total_registered_price total_price total_credit_price previous_balance_amount
        previous_credit_balance_amount previous_extra_credit_balance_amount submit_date free_credit_type
      ]

      sql =
        <<-SQL
          select #{user_balances_columns.join(', ')}
          from res_logistic_user
          where entity_id = #{agent_id}
          order by entity_id DESC
        SQL

      user_balances = execute_sql(sql).to_a

      sql =
        <<-SQL
          select #{order_balances_columns.join(', ')}
          from res_order
          where agent_id = #{agent_id}
          order by entity_id DESC
        SQL

      order_balances = execute_sql(sql).to_a

      sql =
        <<-SQL
          select #{agent_balance_orders_columns.join(', ')}
          from res_agent_balance_order
          where agent_id = #{agent_id}
          order by entity_id DESC
        SQL

      agent_balance_orders = execute_sql(sql).to_a
      
      disply_tables(
        data: agent_balance_orders,
        columns: agent_balance_orders_columns,
        options: {
          title: 'AGENT_BALANCE_ORDERS',
          filters: {
            submit_date: proc_format_datetime
          }
        }
      )      
      
      disply_tables(
        data: order_balances,
        columns: order_balances_columns,
        options: {
          title: 'ORDER_BALANCES',
          filters: {
            purchase_date: proc_format_datetime
          }
        }
      )      
      
      disply_tables(
        data: user_balances,
        columns: user_balances_columns,
        options: {
          title: 'RES_LOGISTIC_USER',
        }
      )

      info_msg("\n= = = = = = = = = End statistic #{time + 1} time(s) at #{Time.now} = = = = = = = = =\n")
      sleep(delay.to_i)
    end
  end

  # rake -f rake_tests/agents.rake agents:turn_on_off_drop_off MODE=dev TURN_ON=false
  task turn_on_off_drop_off: :environment do
    dashboard_logistic_login!

    turn_on = ENV['TURN_ON'] == 'true'
    Backend::App::LogisticDropoffLocations.by_parameters(limit: 999).each do |drl|
      begin
        resp = put("logistics/dropoff_locations/#{drl.id}", {id: drl.id, is_suspended: !turn_on }, api_token)
        address = drl.address
        address.is_hidden = !turn_on
        address.save
      rescue Exception => e
      end
    end
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


# agent_balance_orders.each do |agent_balance_order|
#   row =
#     agent_balance_order_columns.map do |e| 
#       "#{e.to_s.split('_').map{|e| e[0].upcase}.join('_')}: #{agent_balance_order[e]}"
#     end
#   puts "ID ##{agent_balance_order[:entity_id]} - #{build_colunms_with_color(row)}"
# end
# order_balances.each do |order_balance|
#   row =
#     order_balance_columns.map do |e| 
#       "#{e.to_s.split('_').map{|e| e[0].upcase}.join('_')}: #{order_balance[e]}"
#     end
#   puts "ID ##{order_balance[:entity_id]} - #{build_colunms_with_color(row)}"
# end
# user_balances.each do |user_balance|
#   row =
#     user_balance_columns.map do |e| 
#       "#{e.to_s.split('_').map{|e| e[0].upcase}.join('_')}: #{user_balance[e]}"
#     end
#   puts "ID ##{user_balance[:entity_id]} - #{build_colunms_with_color(row)}"
# end
