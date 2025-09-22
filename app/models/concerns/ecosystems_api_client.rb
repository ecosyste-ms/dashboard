module EcosystemsApiClient
  extend ActiveSupport::Concern

  private

  def ecosystems_api_request(url, method: :get, body: nil, headers: {})
    conn = Faraday.new(url: url) do |faraday|
      faraday.headers['User-Agent'] = 'dashboard.ecosyste.ms'
      faraday.headers['X-Source'] = 'dashboard.ecosyste.ms'
      faraday.headers['X-API-Key'] = ENV['ECOSYSTEMS_API_KEY'] if ENV['ECOSYSTEMS_API_KEY']
      headers.each { |k, v| faraday.headers[k] = v }
      faraday.request :json
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    case method
    when :get
      conn.get
    when :post
      conn.post do |req|
        req.body = body if body
      end
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end
  end

  def fetch_json_with_retry(url, max_retries: 3)
    retries = 0
    begin
      response = ecosystems_api_request(url)
      return nil unless response&.success?
      JSON.parse(response.body)
    rescue => e
      retries += 1
      if retries <= max_retries
        sleep(retries * 2) # exponential backoff
        retry
      else
        Rails.logger.error "Failed to fetch #{url} after #{max_retries} retries: #{e.message}"
        nil
      end
    end
  end

  def fetch_paginated_data(base_url, per_page: 100, max_pages: 100)
    results = []
    page = 1
    
    loop do
      url = "#{base_url}#{base_url.include?('?') ? '&' : '?'}per_page=#{per_page}&page=#{page}"
      response = ecosystems_api_request(url)
      
      return results unless response&.success?
      
      data = JSON.parse(response.body)
      break if data.empty?
      
      results.concat(data)
      
      page += 1
      break if page > max_pages
    end
    
    results
  end
end