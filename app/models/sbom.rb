class Sbom < ApplicationRecord

  validates :raw, presence: true

  def convert
    Dir.mktmpdir do |dir|
      # write raw sbom to file
      File.open("#{dir}/sbom.txt", "w") { |f| f.write(raw) }
      puts "Wrote raw sbom to sbom.txt"

      command = "syft convert #{dir}/sbom.txt -o syft-json"

      result = `#{command}`
      update!(converted: result)
    end
  end

  def converted_json
    JSON.parse(converted)
  rescue
    nil
  end

  def artifacts
    return [] unless converted_json
      
    converted_json["artifacts"]
  end

  def packageurls
    artifacts.map { |a| PackageURL.parse a["purl"] }
  end

  def find_packages
    @packages ||= Package.includes(project: :collective).package_urls(packageurls.map(&:to_s))
  end

  def find_projects
    @projects ||= @packages.map(&:project)
  end

  def find_project(purl)
    find_packages.select { |p| p.purl == Project.purl_without_version(purl) }.first&.project
  end

  # Extract PURLs from raw SBOM JSON (handles both CycloneDX and SPDX formats)
  def self.extract_purls_from_json(json)
    purls = []

    if json['bomFormat'] == 'CycloneDX' && json['components']
      purls = json['components'].map { |c| c['purl'] }.compact
    elsif json['spdxVersion'] && json['packages']
      purls = json['packages'].flat_map { |p| 
        Array(p['externalRefs']).select { |ref| ref['referenceType'] == 'purl' }.map { |ref| ref['referenceLocator'] } 
      }.compact
    end

    purls.uniq
  end

  # Convert PURLs to project repository URLs using various lookup strategies
  def self.fetch_project_urls_from_purls(purls)
    urls = []
    purls.each do |purl|
      begin
        # First try local package lookup
        pkg_relation = Package.package_url(purl)
        if pkg_relation && (pkg = pkg_relation.first)
          if pkg.repository_url.present?
            urls << pkg.repository_url
          elsif pkg.project&.url.present?
            urls << pkg.project.url
          end
          next # Found in local packages, skip to next PURL
        end
        
        # Handle pkg:github/ PURLs with direct URL construction
        if purl.start_with?('pkg:github/')
          # Convert GitHub PURL to URL
          # Format: pkg:github/owner/repo@version or pkg:github/action@version
          purl_without_prefix = purl.sub('pkg:github/', '')
          parts = purl_without_prefix.split('/')
          
          if parts.length >= 2
            # Format: owner/repo@version
            owner = parts[0]
            repo_with_version = parts[1]
            repo = repo_with_version&.split('@')&.first
            
            if owner.present? && repo.present?
              urls << "https://github.com/#{owner}/#{repo}"
              next # Successfully handled, skip to next PURL
            end
          elsif parts.length == 1
            # Format: action@version (single part)
            action_with_version = parts[0]
            action = action_with_version&.split('@')&.first
            
            if action.present?
              # Assume it's an action in the 'actions' org if no owner specified
              urls << "https://github.com/actions/#{action}"
              next # Successfully handled, skip to next PURL
            end
          end
        end
        
        # For all other PURL types (including pkg:githubactions/), use API lookup
        conn = Faraday.new do |f|
          f.options.timeout = 10  # 10 seconds timeout
          f.options.open_timeout = 5  # 5 seconds to establish connection
          f.request :retry, max: 2, interval: 1, backoff_factor: 2, 
                    retry_statuses: [429, 500, 502, 503, 504],
                    methods: [:get]
        end
        
        resp = conn.get("https://packages.ecosyste.ms/api/v1/packages/lookup?purl=#{purl}")
        if resp.status == 200
          data = JSON.parse(resp.body)
          pkg = data.first
          next unless pkg
          urls << pkg['repository_url'] if pkg['repository_url'].present?
        end
      rescue Faraday::Error, JSON::ParserError => e
        Rails.logger.error "Error processing PURL #{purl}: #{e.message}"
        next # Continue with next PURL instead of failing the entire import
      rescue => e
        Rails.logger.error "Unexpected error processing PURL #{purl}: #{e.message}"
        next # Continue with next PURL instead of failing the entire import
      end
    end
    urls.uniq
  end
end
