module ProjectsHelper
  # Override Rails URL helpers to generate clean project URLs without encoding
  def project_path(project)
    return super(project) if project.slug.blank?
    
    # Basic security check - prevent obvious path traversal
    if project.slug.include?('..')
      Rails.logger.warn "Potential path traversal attempt: #{project.slug}"
      return super(project)
    end
    
    "/projects/#{project.slug}"
  end

  def project_url(project, **options)
    # Use Rails.application.routes.default_url_options for security
    host = options[:host] || Rails.application.routes.default_url_options[:host] || request.host
    port = Rails.application.routes.default_url_options[:port]
    host_with_port = port ? "#{host}:#{port}" : host
    
    # Force HTTPS in production, allow protocol override only in development
    protocol = if Rails.env.production?
      'https'
    else
      options[:protocol] || (request.ssl? ? 'https' : 'http')
    end
    
    "#{protocol}://#{host_with_port}#{project_path(project)}"
  end

  # Generate project sub-page path helpers dynamically
  %w[packages issues releases commits advisories security productivity 
     responsiveness finance engagement adoption dependencies].each do |action|
    
    define_method "#{action}_project_path" do |project, *args|
      if args.any?
        # For backwards compatibility, fall back to tab-based URL with args
        "#{project_path(project)}?tab=#{action}"
      else
        "#{project_path(project)}?tab=#{action}"
      end
    end

    # Also define collection project helpers
    define_method "#{action}_collection_project_path" do |collection, project, *args|
      base_path = if project.slug.blank?
        collection_project_path(collection, project)
      else
        if project.slug.include?('..')
          Rails.logger.warn "Potential path traversal attempt: #{project.slug}"
          collection_project_path(collection, project)
        else
          "/collections/#{collection.to_param}/projects/#{project.slug}"
        end
      end
      
      "#{base_path}?tab=#{action}"
    end
  end
  
  # Generate remaining project action helpers that are NOT tabs
  %w[sync meta syncing owner_collection add_to_list remove_from_list 
     create_collection_from_dependencies].each do |action|
    
    define_method "#{action}_project_path" do |project, *args|
      "#{project_path(project)}/#{action}"
    end

    define_method "#{action}_collection_project_path" do |collection, project, *args|
      base_path = if project.slug.blank?
        collection_project_path(collection, project)
      else
        if project.slug.include?('..')
          Rails.logger.warn "Potential path traversal attempt: #{project.slug}"
          collection_project_path(collection, project)
        else
          "/collections/#{collection.to_param}/projects/#{project.slug}"
        end
      end
      
      "#{base_path}/#{action}"
    end
  end

  # Override main collection project path
  def collection_project_path(collection, project, *args)
    return super(collection, project, *args) if args.any?
    return super(collection, project) if project.slug.blank?
    
    if project.slug.include?('..')
      Rails.logger.warn "Potential path traversal attempt: #{project.slug}"
      return super(collection, project)
    end
    
    "/collections/#{collection.to_param}/projects/#{project.slug}"
  end

  # Handle URL methods dynamically by converting path methods to URLs
  def method_missing(method_name, *args, **kwargs, &block)
    method_str = method_name.to_s
    
    # Handle project URL methods (either standalone or collection-based)
    if method_str.end_with?('_project_url')
      path_method = method_str.sub('_url', '_path')
      
      if respond_to?(path_method)
        if method_str.include?('_collection_project_url') && args.length >= 2
          # Collection project URL: e.g., issues_collection_project_url(collection, project)
          collection, project = args[0], args[1]
          path = send(path_method, collection, project)
        elsif args.length >= 1 && args.first.respond_to?(:slug)
          # Standalone project URL: e.g., issues_project_url(project)
          project = args.first
          path = send(path_method, project)
        else
          return super
        end
        
        host = kwargs[:host] || Rails.application.routes.default_url_options[:host] || request.host
        port = Rails.application.routes.default_url_options[:port]
        host_with_port = port ? "#{host}:#{port}" : host
        
        protocol = if Rails.env.production?
          'https'
        else
          kwargs[:protocol] || (request.ssl? ? 'https' : 'http')
        end
        
        return "#{protocol}://#{host_with_port}#{path}"
      end
    end
    
    super
  end

  def respond_to_missing?(method_name, include_private = false)
    method_str = method_name.to_s
    (method_str.end_with?('_project_url') && respond_to?(method_str.sub('_url', '_path'))) || super
  end
end