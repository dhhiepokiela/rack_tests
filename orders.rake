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
end

