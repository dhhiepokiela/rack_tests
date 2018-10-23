require_relative 'environment.rb'

namespace :system do
  task console: :environment do |t| 
    binding.pry
    # irb_cmd([
    #   "order = Backend::App::Orders.by_parameters(code: 'MD263445', limit: 1)",
    #   "puts order.code"
    # ])
    # run_sys_cmd(['rake elasticsearch:resync_fail_orders'])
    # run_sys_cmd(['sudo -s', 'cd /tmp', 'ls'])
  end
  
  task log_nginx_dev1: :environment do |t|
    starting(t)
    run_sys_cmd(['sudo tail -f /var/log/nginx/access.log'], ssh_servers: ['dev1'], sudo: false)
    pass(t)
  end

  task reload_price_check_cache: :environment do |t|
    starting(t)
    run_sys_cmd(['ruby ./tools/price_check/reload_cache.rb'])
    pass(t)
  end

  task reload_cache_full_power_agent_time_frame: :environment do |t|
    starting(t)
    run_sys_cmd(['./stopserver.sh', './startserver.sh', 'ruby ./tools/update_cache_full_power_agent_time_frame.rb'])
    pass(t)
  end

  task restart_system: :environment do |t|
    starting(t)
    run_sys_cmd(['./stopserver.sh', './startserver.sh'])
    pass(t)
  end
end
