require 'faraday/typhoeus'
Faraday.default_adapter = :typhoeus

Faraday.default_connection = Faraday::Connection.new do |builder|
  builder.response :follow_redirects
  builder.request :url_encoded
  builder.adapter Faraday.default_adapter
  builder.options.timeout = 10
  builder.options.open_timeout = 10
  builder.headers['User-Agent'] = 'dashboard.ecosyste.ms'
end
