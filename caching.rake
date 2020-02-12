# frozen_string_literal: true

require_relative 'environment.rb'

namespace :caching do
  desc 'All Follow'
  task all: :environment do |t|
    starting(t)
    run('caching:h_ttl')
    run('caching:ttl')
    run('caching:existed')
    run('caching:scan_keys')
    run('caching:all_keys')
    run('caching:fetch')
    run('caching:get')
    run('caching:update')
    run('caching:delete')
    run('caching:delete_data_for')
    run('caching:cache_expire')
    run('caching:convert_hash_key_to_key_case_1')
    run('caching:convert_hash_key_to_key_case_2')
    pass(t)
  end

  desc 'Test CacheManager.h_ttl(namespace, key)'
  task h_ttl: :environment do |t|
    starting(t)

    Backend::App::CacheManager.h_delete(namespace: data[:namespace], key: data[:key1])

    expect("Set hkey #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.h_fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.h_get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Check TTL for hkey #{data[:key1]}", true) do
      remaining_time = Backend::App::CacheManager.h_ttl(data[:namespace])
      remaining_time.positive? && remaining_time <= data[:cache_expire]
    end

    expect("Check TTL for hkey #{data[:key1]}", true) do
      Backend::App::CacheManager.h_ttl(data[:namespace]) >= data[:cache_expire] - 1
    end

    Backend::App::CacheManager.h_delete(namespace: data[:namespace], key: data[:key1])

  end

  desc 'Test CacheManager.ttl(namespace, key)'
  task ttl: :environment do |t|
    starting(t)

    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Check TTL for key #{data[:key1]}", true) do
      remaining_time = Backend::App::CacheManager.ttl(data[:namespace], data[:key1])
      remaining_time.positive? && remaining_time <= data[:cache_expire]
    end

    expect("Check TTL for key #{data[:key1]}", true) do
      Backend::App::CacheManager.ttl(data[:namespace], data[:key1]) >= data[:cache_expire] - 1
    end

    Backend::App::CacheManager.delete(namespace: data[:namespace], key: data[:key1])

  end

  desc 'Test CacheManager.existed?(namespace, key)'
  task existed: :environment do |t|
    starting(t)
    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Key #{data[:key1]} is existed", true) do
      Backend::App::CacheManager.existed?(data[:namespace], data[:key1])
    end

  end

  desc 'Test CacheManager.scan_keys(namespace, sub_string)'
  task scan_keys: :environment do |t|
    starting(t)
    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Set key #{data[:key2]} is #{data[:val2]}", data[:val2]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key2]) { data[:val2] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key2])
    end

    expect("Scan namespace #{data[:namespace]}", 2) do
      Backend::App::CacheManager.scan_keys(data[:namespace], 'ey').count
    end

    expect("Scan namespace #{data[:namespace]}", 2) do
      Backend::App::CacheManager.scan_keys(data[:namespace], 'Key').count
    end

    expect("Scan namespace #{data[:namespace]}", 1) do
      Backend::App::CacheManager.scan_keys(data[:namespace], 'y #1').count
    end

  end

  desc 'Test CacheManager.all_keys(namespace: nil)'
  task all_keys: :environment do |t|
    starting(t)

    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Set key #{data[:key2]} is #{data[:val2]}", data[:val2]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key2]) { data[:val2] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key2])
    end

    expect("Set key #{data[:key3]} is #{data[:val3]}", data[:val3]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key3]) { data[:val3] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key3])
    end

    expect("All keys of namespace #{data[:namespace]}", 3) do
      Backend::App::CacheManager.all_keys(namespace: data[:namespace]).count
    end

  end

  desc 'Test CacheManager.fetch(namespace, cached_key, options = {}, &block)'
  task fetch: :environment do |t|
    starting(t)

    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
    end

    expect("Get key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Fetch key #{data[:key1]} no return new data", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { 'New Data' }
    end

  end

  desc 'Test CacheManager.get(namespace: nil, key: nil)'
  task get: :environment do |t|
    starting(t)

    expect("Set and get key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

  end

  desc 'Test CacheManager.update(namespace: nil, key: nil, data: nil)'
  task update: :environment do |t|
    starting(t)
    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
    end

    expect("Get key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Update key #{data[:key1]} is to New Data", 'New Data') do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
      Backend::App::CacheManager.update(namespace: data[:namespace], key: data[:key1], data: 'New Data')
    end

  end

  desc 'Test CacheManager.delete(namespace: nil, key: nil)'
  task delete: :environment do |t|
    starting(t)

    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.delete(namespace: data[:namespace], key: data[:key1])
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Delete key #{data[:key1]}", nil) do
      Backend::App::CacheManager.delete(namespace: data[:namespace], key: data[:key1])
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

  end

  desc 'Test CacheManager.delete_data_for(namespace: nil)'
  task delete_data_for: :environment do |t|
    starting(t)

    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace_l], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace_l], key: data[:key1])
    end

    expect("Set key #{data[:key2]} is #{data[:val2]}", data[:val2]) do
      Backend::App::CacheManager.fetch(data[:namespace_l], data[:key2]) { data[:val2] }
      Backend::App::CacheManager.get(namespace: data[:namespace_l], key: data[:key2])
    end

    expect("Set key #{data[:key3]} is #{data[:val3]}", data[:val3]) do
      Backend::App::CacheManager.fetch(data[:namespace_l], data[:key3]) { data[:val3] }
      Backend::App::CacheManager.get(namespace: data[:namespace_l], key: data[:key3])
    end

    expect("All keys of namespace #{data[:namespace_l]}", 3) do
      Backend::App::CacheManager.all_keys(namespace: data[:namespace_l]).count
    end

    expect("Delete all keys for namespace #{data[:namespace_l]}", 0) do
      Backend::App::CacheManager.delete_data_for(namespace: data[:namespace_l])
      Backend::App::CacheManager.all_keys(namespace: data[:namespace_l]).count
    end

  end

  desc 'Test CacheManager.convert_hash_key_to_key_case_1(namespace, key)'
  task convert_hash_key_to_key_case_1: :environment do |t|
    starting(t)
    # Expired in 4s
    convert_hkey_to_key(data[:namespace])

  end

  desc 'Test CacheManager.convert_hash_key_to_key_case_2(namespace, key)'
  task convert_hash_key_to_key_case_2: :environment do |t|
    starting(t)
    # Never expired
    convert_hkey_to_key(:device_token)

  end

  desc 'Cache expire correctly'
  task cache_expire: :environment do |t|
    starting(t)

    clear_all_data

    expect("Namespace :#{data[:namespace]} should expired in #{data[:cache_expire]}s", data[:cache_expire]) do
      Backend::App::CacheManager.expired_time_for(Backend::App::CacheManager::CACHE_NAME_SPACE[data[:namespace]])
    end

    expect("Set key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key1]) { data[:val1] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    delay(2)

    expect("Set key #{data[:key2]} is #{data[:val2]}", data[:val2]) do
      Backend::App::CacheManager.fetch(data[:namespace], data[:key2]) { data[:val2] }
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key2])
    end

    expect("Key #{data[:key1]} is not expired", data[:val1]) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    delay(3)

    expect("Key #{data[:key1]} is expired", nil) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Key #{data[:key2]} is not expired", data[:val2]) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key2])
    end

    delay(2)

    expect("Key #{data[:key1]} is expired", nil) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key1])
    end

    expect("Key #{data[:key2]} is expired", nil) do
      Backend::App::CacheManager.get(namespace: data[:namespace], key: data[:key2])
    end

  end

  private

  def convert_hkey_to_key(namespace)
    Backend::App::CacheManager.delete(namespace: namespace, key: data[:key1])
    Backend::App::CacheManager.h_delete(namespace: namespace, key: data[:key1])

    expect("Set hkey #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.h_fetch(namespace, data[:key1]) { data[:val1] }
      Backend::App::CacheManager.h_get(namespace: namespace, key: data[:key1])
    end

    current_ttl = Backend::App::CacheManager.h_ttl(namespace)
    details_msg('INFO', "Current PTTL #{current_ttl}", color: :default)

    expect("Check current PTTL for hkey #{data[:key1]}", true) do
      if current_ttl == -1
        true
      else
        c1 = current_ttl.positive? && current_ttl <= data[:cache_expire]
        c2 = current_ttl >= (data[:cache_expire] - 1)

        c1 && c2
      end
    end

    expect("Get key #{data[:key1]} is nil", nil) do
      Backend::App::CacheManager.get(namespace: namespace, key: data[:key1])
    end

    sleep(0.5)

    Backend::App::CacheManager.convert_hkey_to_key(namespace, data[:key1])

    expect("Get key #{data[:key1]} is #{data[:val1]}", data[:val1]) do
      Backend::App::CacheManager.get(namespace: namespace, key: data[:key1])
    end

    new_ttl = Backend::App::CacheManager.ttl(namespace, data[:key1])
    details_msg('INFO', "PTTL - Current: #{current_ttl} vs New: #{new_ttl}", color: :default)

    expect("Check PTTL for key #{data[:key1]}", true) do
      if new_ttl == current_ttl && current_ttl == -1
        true
      else
        new_ttl.positive? && new_ttl <= current_ttl && new_ttl >= current_ttl - 1.5
      end
    end

    Backend::App::CacheManager.delete(namespace: namespace, key: data[:key1])
    Backend::App::CacheManager.h_delete(namespace: namespace, key: data[:key1])
  end

  def data
    {
      namespace: :data_set,
      namespace_l: :comment,
      cache_expire: 4,
      key1: 'Key #1',
      key2: 'Key #2',
      key3: 'Key #3',
      val1: { first_name: 'Hiep', last_name: 'Dinh' },
      val2: 222,
      val3: 333,
    }
  end

  def clear_all_data
    # Clean data
    Backend::App::CacheManager.delete(namespace: data[:namespace], key: data[:key1])
    Backend::App::CacheManager.delete(namespace: data[:namespace], key: data[:key2])
    Backend::App::CacheManager.delete(namespace: data[:namespace], key: data[:key3])
  end
end
