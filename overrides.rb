Array.class_eval do
  # c = [1, 2, 3, 4, 5, 10, 6, "1"]
  # pr = [6, 7, 8, 9, "10", "1", 1, "2"]
  # pn = pr.shuffle_contain(c)
  # p pn.shuffle_contain(c)
  # => [1, 6, "1"]
  def shuffle_contain(arr)
    arr - self
  end

  def shuffle_contain?(arr)
    shuffle_contain(arr).empty?
  end

  def shuffle_contain_each_other?(arr)
    shuffle_contain(arr).empty? && arr.shuffle_contain(self).empty?
  end
end

Time.class_eval do
  def unix_time
    strftime('%s')
  end
end

Integer.class_eval do
  def calc_time_during(key, value)
    case key
    when 'seconds'
      value.to_f
    when 'minutes'
      value.to_f * 60
    when 'hours'
      value.to_f * 60 * 60
    when 'days'
      value.to_f * 60 * 60 * 24
    end
  end

  %w[seconds minutes hours days].each do |time|
    define_method("#{time}_from_now") do
      Time.now.getlocal('+07:00') + calc_time_during(time, self)
    end

    define_method("#{time}_ago") do
      Time.now.getlocal('+07:00') - calc_time_during(time, self)
    end
  end
end

OpenSSL::PKey::DSA.class_eval do
  def ssh_do_sign(data)
    sig = sign( OpenSSL::Digest::SHA1.new, data)
    a1sig = OpenSSL::ASN1.decode( sig )

    sig_r = a1sig.value[0].value.to_s(2)
    sig_s = a1sig.value[1].value.to_s(2)

    if sig_r.length > 20 || sig_s.length > 20
      raise OpenSSL::PKey::DSAError, "bad sig size"
    end

    sig_r = "\0" * ( 20 - sig_r.length ) + sig_r if sig_r.length < 20
    sig_s = "\0" * ( 20 - sig_s.length ) + sig_s if sig_s.length < 20

    return sig_r + sig_s
  end
end
