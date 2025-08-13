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
     responsiveness finance engagement adoption dependencies sync meta 
     syncing owner_collection add_to_list remove_from_list 
     create_collection_from_dependencies].each do |action|
    
    define_method "#{action}_project_path" do |project, *args|
      return super(project, *args) if args.any? # Fall back to Rails for collection routes
      "#{project_path(project)}/#{action}"
    end
  end

  # Handle URL methods dynamically by converting path methods to URLs
  def method_missing(method_name, *args, **kwargs, &block)
    if method_name.to_s.end_with?('_project_url') && args.length >= 1 && args.first.respond_to?(:slug)
      # Convert URL method to path method
      path_method = method_name.to_s.sub('_url', '_path')
      
      if respond_to?(path_method)
        project = args.first
        path = send(path_method, project)
        
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
    method_name.to_s.end_with?('_project_url') && respond_to?(method_name.to_s.sub('_url', '_path')) || super
  end
end