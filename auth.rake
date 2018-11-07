require_relative 'environment.rb'

namespace :auth do
  task all: :environment do
    run('auth:user_login')
    run('auth:client_login')
    run('auth:logistic_login')
    run('auth:agent_login')
  end

  task force_logout: :environment do |t|
    starting(t)
    user = Backend::App::Users.by_parameters(phone: '0898157886', limit: 1)
    details_msg('INFO', 'Login ...')
    resp = user_login(user.phone, '123456')
    resp.status_200?

    details_msg('INFO', 'Auth success ...')
    resp = get('auth', {}, api_token)
    resp.status_200?

    Backend::App::MiscServices::ForceLogout.force_logout!(user)

    details_msg('INFO', 'Auth failed ...')
    resp = get('auth', {}, api_token)
    resp.status_403?

    # Reset after trigger logout
    details_msg('INFO', 'Auth success ...')
    resp = get('auth', {}, api_token)
    resp.status_200?
    
    pass(t)
  end

  task user_login: :environment do |t|
    starting(t)
    details_msg('INFO', 'Login user with 11 digits ...')
    resp = user_login('01285286828', '123456')
    resp.status_200?

    details_msg('INFO', 'Login user with 10 digits ...')
    resp = user_login('0898157886', '123456')
    resp.status_200?

    details_msg('INFO', 'Login user with 10 digits after converted ...')
    resp = user_login('0785286828', '123456')
    resp.status_200?

    pass(t)
  end

  task client_login: :environment do |t|
    starting(t)
    details_msg('INFO', 'Login client with 11 digits ...')
    resp = client_login('0785286828', '123456')
    resp.status_200?

    details_msg('INFO', 'Login client with 10 digits ...')
    resp = client_login('0974818666', '123456')
    resp.status_200?

    details_msg('INFO', 'Login client with 10 digits after converted ...')
    resp = client_login('0785286828', '123456')
    resp.status_200?

    pass(t)
  end

  task logistic_login: :environment do |t|
    starting(t)
    details_msg('INFO', 'Login logistic with 10 digits ...')
    resp = logistic_login('0999999999', '123456')
    resp.status_200?

    pass(t)
  end

  task agent_login: :environment do |t|
    starting(t)
    details_msg('INFO', 'Login agent with 11 digits ...')
    resp = agent_login('01646320010', '111111')
    resp.status_200?

    details_msg('INFO', 'Login agent with 10 digits ...')
    resp = agent_login('0999999025', '123456')
    resp.status_200?

    details_msg('INFO', 'Login agent with 10 digits after converted ...')
    resp = agent_login('0346320010', '111111')
    resp.status_200?

    pass(t)
  end
end
