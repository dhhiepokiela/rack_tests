require_relative 'environment.rb'


namespace :system do
  task console: :environment do |t|
    binding.pry
  end

  task benchmark: :environment do |t|
    starting(t)
    dashboard_logistic_login!
    ENV['TIMES'].to_i.times do
      print_memory_usage do
        print_time_spent do
          resp = get('logistics/orders/28033677/get_okiela_drop_off_address', {}, api_token)
          resp.status_200?
        end
      end
    end
    pass(t)
  end

  task log_nginx_dev1: :environment do |t|
    starting(t)
    run_sys_cmd(['sudo tail -f /var/log/nginx/access.log'], ssh_servers: ['dev1'], sudo: false)
    pass(t)
  end

  task force_logout: :environment do |t|
    starting(t)
    irb_cmd([
      "user = Backend::App::LogisticUsers.by_parameters(phone: '01010101017', limit: 1)",
      "Backend::App::MiscServices::ForceLogout.force_logout!(user)"
    ])
    pass(t)
  end

  task clear_statistic: :environment do |t|
    ENV['MODE'] = 'dev'
    starting(t)
    irb_cmd([
      "user = Backend::App::Users.by_parameters(phone: '0386222220')",
      "user.get_ex_client_financial_info(force_reload: true)"
    ])
    pass(t)
  end

  task reset_get_public_okiela_drop_off_address: :environment do |t|
    starting(t)
    commands = []
    commands << "file_path = $_CONFIG['system']['files']['cache_ip_address']"
    commands << 'File.open(file_path, "a+") { |file| file.truncate(0); file.write("#{{}.to_json}") }'
    irb_cmd(commands, ssh_servers: %w[dev2])
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
