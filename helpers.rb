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
  {
    'Auth-Token' => ENV['Auth-Token'],
  }
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

def run(task_name, sub_task = false)
  if sub_task
    puts "~~>> SUB TASK: #{task_name.upcase}".colorize(:light_magenta)
  else
    puts "= = = = = #{task_name.upcase} IS RUNNING ON SERVER #{ENV['BASE_URL_API']} ... = = = = =".colorize(:cyan)
  end
  Rake::Task[task_name].reenable
  Rake::Task[task_name].invoke
end

def change_to_local_server!
  ENV['BASE_URL_API'] = ENV['LOCAL_BASE_URL_API']
end

def change_to_dev_server!
  ENV['BASE_URL_API'] = ENV['DEV_BASE_URL_API']
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

def client_login(phone, password)
  change_to_dev_server!
  data =
    post('auth/login_client', {
      phone: phone, 
      password: password
    }).store_api_token_and_return
  change_to_local_server!
  data
end

def logistic_login(phone, password)
  change_to_dev_server!
  data =
    post('auth/login_logistic', {
      phone: phone, 
      password: password
    }).store_api_token_and_return
  change_to_local_server!
  data
end

def agent_login(phone, password)
  change_to_dev_server!
  data =
    post('auth/login_agent', {
      phone: phone,
      password: password,
      login_type: 'swagger_agent'
    }).store_api_token_and_return
  change_to_local_server!
  data
end

def dashboard_logistic_login!
  logistic_login('0978838249', '889052')
end

def login_agent!
  # KP 1 Thị Xã Thủ Dầu Một Phường Định Hòa Bình Dương
  # agent_login(ENV['AGENT_PHONE'], '111111')
  agent_login('01010101017', '123456')
  # agent_login('01248760542', '123456')
  # agent_login('01234567890', '123456')
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

def error_msg(msg = '')
  puts msg.colorize(:red)
end

def force_reset_default_password_by_phone(phone)
  sql =
    <<-SQL
      update res_user
      set `auth_pw_hash` = '7c4a8d09ca3762af61e59520943dc26494f8941b'
      where phone = '#{phone}'
    SQL

  db = DatabasePool.get_connector
  db.query(sql: sql)
end