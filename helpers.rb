def print_memory_usage
  memory_before = `ps -o rss= -p #{Process.pid}`.to_i
  yield
  memory_after = `ps -o rss= -p #{Process.pid}`.to_i

  puts "Memory: #{((memory_after - memory_before) / 1024.0).round(2)} MB" if debug_mode?
end

def print_time_spent
  time = Benchmark.realtime do
    yield
  end

  puts "Time: #{time.round(2)}" if debug_mode?
end

# # Usage
# print_memory_usage do
#   print_time_spent do
#     # xxx
#   end
# end

def build_headers(include_api = true)
  headers = {
    'referer' => '/swagger/index.html'
  }

  headers
end

def api_token
  api_secret.merge('Auth-Token' => ENV['Auth-Token'])
end

def api_secret
  {
    'API-Secret' => ENV['API_SECRET']
  }
end

def get(path, params = {}, headers = {})
  HTTParty.get("#{ENV['BASE_URL_API']}/#{path}", query: params, headers: build_headers.merge(headers), timeout: ENV['REQUEST_TIMEOUT'].to_i)
end

def put(path, params = {}, headers = {})
  HTTParty.put("#{ENV['BASE_URL_API']}/#{path}", query: params, headers: build_headers.merge(headers), timeout: ENV['REQUEST_TIMEOUT'].to_i)
end

def post(path, params = {}, headers = {})
  HTTParty.post("#{ENV['BASE_URL_API']}/#{path}", body: params, headers: build_headers.merge(headers), timeout: ENV['REQUEST_TIMEOUT'].to_i)
end

def debug_mode?
  ENV['DEBUG_MODE'] == true
end

def run(task, sub_task = false)
  if sub_task
    puts "~~>> SUB TASK: #{task.upcase}".colorize(:light_magenta)
  else
    # puts "= = = = = #{task.upcase} IS RUNNING ON SERVER #{ENV['BASE_URL_API']} ... = = = = =".colorize(:cyan)
  end
  Rake::Task[task].reenable
  Rake::Task[task].invoke
end

def change_to_local_server!
  ENV['BASE_URL_API'] = ENV['LOCAL_BASE_URL_API']
end

def change_to_dev_server!
  ENV['BASE_URL_API'] = ENV['DEV_BASE_URL_API']
end

def set_default_server!
  ENV['BASE_URL_API'] = 
    case ENV['MODE'].to_s.downcase
    when 'dev'
      ENV['DEV_BASE_URL_API']
    else
      ENV['LOCAL_BASE_URL_API']
    end
end

def environment_dev?
  ENV['MODE'].to_s.downcase == 'dev'
end

HTTParty::Response.class_eval do
  [200, 201, 400, 403, 404, 500].each do |code|
    define_method("status_#{code}?") do
      code_returned = self['meta']['code']
      return if code_returned == code
      msg = "Status expected #{code} but got #{code_returned}. #{self}"
      raise msg.colorize(:red)
    end
  end

  def message_eq?(msg = '')
    self_msg = self['notifications']['message']
    return true if self_msg == msg
    raise "Message was expected is: #{msg} but got: #{self_msg}".colorize(:red)
  end

  def message_include?(msg = '')
    self_msg = self['notifications']['message']
    return true if self_msg.include?(msg)
    raise "Message was expected is: #{msg} but got: #{self_msg}".colorize(:red)
  end

  def eq?(value, value_expected)
    return true if value_expected == value
    raise "Value was expected is: #{value_expected} but got: #{value}".colorize(:red)
  end

  def not_eq?(value, value_expected)
    return true unless value_expected == value
    raise "Value was expected is: #{value_expected} and got: #{value}".colorize(:red)
  end

  def include?(arr, element)
    return true if arr.include?(element)
    raise "Value was expected must include in: #{arr} but element got: #{element}".colorize(:red)
  end

  def not_include?(arr, element)
    return true unless arr.include?(element)
    raise "Value was expected must not include in: #{arr} but element got: #{element}".colorize(:red)
  end

  def lt?(v1, v2)
    return true if v1 < v2
    raise "Value 1 is: #{v1} not less than #{v2}".colorize(:red)
  end

  def gt?(v1, v2)
    return true if v1 > v2
    raise "Value 1 is: #{v1} not greater than #{v2}".colorize(:red)
  end

  def store_api_token_and_return
    return self unless [200, 201].include?(self['meta']['code']) || self['api_token'].present?
    ENV['Auth-Token'] = self['api_token']['token_string']
    self
  end
end

# {
#   user_login: 'login',
#   client_login: 'login_client',
#   logistic_login: 'login_logistic',
#   agent_login: 'login_agent',
# }.each do ||

def user_login(phone, password)
  change_to_dev_server! if login_on_dev?
  data =
    post('auth/login', {
      phone: phone, 
      password: password
    }).store_api_token_and_return
  set_default_server!
  data
end

def client_login(phone, password)
  change_to_dev_server! if login_on_dev?
  data =
    post('auth/login_client', {
      phone: phone, 
      password: password
    }).store_api_token_and_return
  set_default_server!
  data
end

def logistic_login(phone, password)
  change_to_dev_server! if login_on_dev?
  data =
    post('auth/login_logistic', {
      phone: phone, 
      password: password
    }).store_api_token_and_return
  set_default_server!
  data
end

def agent_login(phone, password)
  change_to_dev_server! if login_on_dev?
  data =
    post('auth/login_agent', {
      phone: phone,
      password: password,
      login_type: 'swagger_agent'
    }).store_api_token_and_return
  set_default_server!
  data
end

def login_on_dev?
  ENV['LOGIN_ON_DEV'] == 'true'
end

def dashboard_logistic_login!
  logistic_login(ENV['ADMIN_DASHBOARD_PHONE'], ENV['ADMIN_DASHBOARD_PASSD'])
end

def login_agent!
  agent_login(ENV['AGENT_PHONE'], ENV['AGENT_PASS'])
end

def get_logistic_user_by_phone(phone)
  Backend::App::LogisticUsers.by_parameters(phone: phone, limit: 1)
end

def get_user_by_phone(phone)
  Backend::App::Users.by_parameters(phone: phone, limit: 1)
end

def get_order_by_code(code)
  Backend::App::Orders.by_parameters(code: code, limit: 1)
end

def get_order_by_id(id)
  Backend::App::Orders.by_id(id)
end

def display_string_colors
  String.colors.each do |p|
    puts "test => #{p}".colorize(p)
  end
end

def details_msg(title = '', msg = '')
  puts "#{title.colorize(:blue)}: #{msg.to_s.colorize(:light_cyan)}"
end

def info_msg(msg = '')
  puts msg.colorize(:blue)
end

def success_msg(msg = '')
  puts msg.colorize(:green)
end

def success_msg_inline(msg = '')
  print msg.colorize(:green)
end

def error_msg(msg = '')
  puts msg.colorize(:red)
end

def error_msg_inline(msg = '')
  print msg.colorize(:red)
end

def starting(task)
  puts "> > > > > > > > > > > > > > > > > > + + + > > > > > > > > > > > > > > > > > >".colorize(:cyan)
  success_msg("# # # Task ##{Digest::MD5.hexdigest(task.__id__.to_s)[0..4].upcase} - #{task} is STARTING ON SERVER #{ENV['BASE_URL_API']} # # #")
end

def pass(task)
  puts "< < < < < < < < < < < < < < < < < < @ @ @ < < < < < < < < < < < < < < < < < <".colorize(:light_red)
  success_msg("# # # Task ##{Digest::MD5.hexdigest(task.__id__.to_s)[0..4].upcase} - #{task} was PASSED ON SERVER #{ENV['BASE_URL_API']}  # # #")
end

def failure(task, description = nil)
  puts "< < < < < < < < < < < < < < < < < < @ @ @ < < < < < < < < < < < < < < < < < <".colorize(:light_red)
  error_msg("# # # Task ##{Digest::MD5.hexdigest(task.__id__.to_s)[0..4].upcase} - #{task} was FAILED # # #")
  details_msg('Details', "#{description}\n") if description.present?
  puts ''
end

def force_reset_default_password_by_phone(phone)
  sql =
    <<-SQL
      update res_user
      set `auth_pw_hash` = '7c4a8d09ca3762af61e59520943dc26494f8941b'
      where phone = '#{phone}'
    SQL

  execute_sql(sql)
end

def db_connection
  DatabasePool.get_connector
end

def execute_sql(sql)
  db_connection.query(sql: sql)
end

def ssh_dev1_exec(exe_commands = [], debug = true)
  ssh_exec('dev1', 'dev', exe_commands, debug)
end

def ssh_dev2_exec(exe_commands = [], debug = true)
  ssh_exec('dev2', 'dev', exe_commands, debug)
end

def ssh_exec(host, user, exe_commands = [], debug = true)
  server_name = "SERVER #{host.upcase}"
  success_msg("\n= = = = = #{server_name} START OUTPUT = = = = =\n")

  @telnet_connection =
    if host == 'dev1'
      @ssh_dev1
    else
      @ssh_dev2
    end

  if @telnet_connection.present?
    details_msg(server_name, "Using last session ...")
  else
    details_msg(server_name, "Connection is establishing ...")
    ssh_connection = Net::SSH.start(host, user)
    @telnet_connection = Net::SSH::Telnet.new(
      'Session' => ssh_connection,
      'Dump_log' => './rake_tests/dump.log',
      'Output_log' => './rake_tests/rakoutput.log',
      'Timeout' => 10 * 60, # seconds
      'Waittime' => 3, # seconds
      'Terminator' => "\r"
    )
    details_msg(server_name, "Connection was established")

    if host == 'dev1'
      @ssh_dev1 = @telnet_connection
    else
      @ssh_dev2 = @telnet_connection
    end
  end

  exe_commands.each_with_index do |command, index|
    output = @telnet_connection.cmd(command)
    next unless debug
    info_msg("\n#{server_name} execute \"#{command}\" (#{index + 1} of #{exe_commands.count})")
    puts output
  end
  success_msg("\n= = = = = SSH #{host.upcase} END OUTPUT = = = = =\n")
  # @telnet_connection.close
end

def sync_es
  details_msg('Action', 'Sync Orders to ES ...')
  run_sys_cmd(['rake elasticsearch:resync_fail_orders'])
end

def run_sys_cmd(commands, ssh_servers: ['dev1', 'dev2'], sudo: true)
  if environment_dev?
    base_commands = []
    if @ssh_dev1.blank? || @ssh_dev2.blank? # last session was do base_commands commands
      base_commands = ['cd ~/trendu_backend', 'pwd']
      base_commands << 'sudo -s' if sudo
    end

    ssh_dev1_exec([base_commands, commands].flatten) if ssh_servers.include?('dev1')
    ssh_dev2_exec([base_commands, commands].flatten) if ssh_servers.include?('dev2')
  else
    commands.each do |command|
      %x( #{command} )
    end
    # Open3.popen3(command) do |stdin, stdout, stderr, thread|
    #   pid = thread.pid
    #   stdout.read.chomp
    #   puts "run_sys_cmd: #{pid} #{command}"
    # end
  end
end

def delay(seconds)
  seconds.times do |i|
    details_msg("INFO", "System will be continue in #{seconds - i} second(s)")
    sleep(1)
  end
end

def check_and_delete_order_on_es(order_id)
  unless (Backend::App::Orders.by_id(order_id, true).id rescue nil)
    details_msg('SYSTEM', "Removing order ##{order_id} on ES")
    HTTParty.delete("http://api-online-dev.okiela.com:9200/okiela/order/#{order_id}")
  end
end