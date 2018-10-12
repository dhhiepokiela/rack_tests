require_relative 'environment.rb'

namespace :system do
  task console: :environment do |t| 
    run_sys_cmd(['rake elasticsearch:resync_fail_orders'])
    # run_sys_cmd(['sudo -s', 'cd /tmp', 'ls'])
  end
end
