module ApplicationHelper
  include Pagy::Frontend

  def meta_title
    [@meta_title, 'Ecosyste.ms: Dashboard'].compact.join(' | ')
  end

  def meta_description
    @meta_description || app_description
  end

  def app_name
    "Dashboard"
  end

  def app_description
    'A web application to visualize and manage open source project data from the Ecosyste.ms API.'
  end

  def obfusticate_email(email)
    return unless email
    email.split('@').map do |part|
      # part.gsub(/./, '*') 
      part.tap { |p| p[1...-1] = "****" }
    end.join('@')
  end

  def period_label(year, month = nil)
    return year.to_s unless month
    Date.new(year, month).strftime("%B %Y")
  rescue ArgumentError
    "Invalid date"
  end

  def distance_of_time_in_words_if_present(time)
    return 'N/A' unless time
    distance_of_time_in_words(time)
  end

  def diff_class(count)
    count > 0 ? 'text-success' : 'text-danger'
  end

  def download_period(downloads_period)
    case downloads_period
    when "last-month"
      "last month"
    when "total"
      "total"
    end
  end

  def period_name(start_date, end_date)
    case @period
    when :day
      start_date.strftime("%A, %B %e, %Y")
    when :week
      start_date.strftime("%B %e, %Y") + " - " + end_date.strftime("%B %e, %Y")
    when :month
      start_date.strftime("%B %Y")
    when :year
      start_date.strftime("%Y")
    end
  end

  def current_period_name
    period_name(@start_date, @end_date)
  end

  def previous_period_name
    period_name(previous_period_start_date, previous_period_end_date)
  end

  def next_period_name
    period_name(next_period_start_date, next_period_end_date)
  end

  def previous_period_start_date
    case @period
    when :day
      @start_date - 1.day
    when :week
      @start_date - 1.week
    when :month
      @start_date - 1.month
    when :year
      @start_date - 1.year
    end
  end

  def previous_period_end_date
    case @period
    when :day
      @end_date - 1.day
    when :week
      @end_date - 1.week
    when :month
      @end_date - 1.month
    when :year
      @end_date - 1.year
    end
  end

  def next_period_start_date
    case @period
    when :day
      @start_date + 1.day
    when :week
      @start_date + 1.week
    when :month
      @start_date + 1.month
    when :year
      @start_date + 1.year
    end
  end

  def next_period_end_date
    case @period
    when :day
      @end_date + 1.day
    when :week
      @end_date + 1.week
    when :month
      @end_date + 1.month
    when :year
      @end_date + 1.year
    end
  end

  def next_period_valid?
    next_period_start_date < Time.now && next_period_end_date < Time.now
  end

  def severity_class(severity)
    case severity.downcase
    when 'low'
      'success'
    when 'moderate'
      'warning'
    when 'high'
      'danger'
    when 'critical'
      'dark'
    else
      'info'
    end
  end

  def project_path_with_collection(project, action = nil, collection = nil)
    collection ||= @collection
    if collection
      case action
      when nil
        collection_project_path(collection, project)
      when 'issues'
        issues_collection_project_path(collection, project)
      when 'releases'
        releases_collection_project_path(collection, project)
      when 'commits'
        commits_collection_project_path(collection, project)
      when 'packages'
        packages_collection_project_path(collection, project)
      when 'advisories'
        advisories_collection_project_path(collection, project)
      when 'adoption'
        adoption_collection_project_path(collection, project)
      when 'engagement'
        engagement_collection_project_path(collection, project)
      when 'dependency'
        dependency_collection_project_path(collection, project)
      when 'productivity'
        productivity_collection_project_path(collection, project)
      when 'finance'
        finance_collection_project_path(collection, project)
      when 'responsiveness'
        responsiveness_collection_project_path(collection, project)
      when 'meta'
        meta_collection_project_path(collection, project)
      else
        collection_project_path(collection, project)
      end
    else
      case action
      when nil
        project_path(project)
      when 'issues'
        issues_project_path(project)
      when 'releases'
        releases_project_path(project)
      when 'commits'
        commits_project_path(project)
      when 'packages'
        packages_project_path(project)
      when 'advisories'
        advisories_project_path(project)
      when 'adoption'
        adoption_project_path(project)
      when 'engagement'
        engagement_project_path(project)
      when 'dependency'
        dependency_project_path(project)
      when 'productivity'
        productivity_project_path(project)
      when 'finance'
        finance_project_path(project)
      when 'responsiveness'
        responsiveness_project_path(project)
      when 'meta'
        meta_project_path(project)
      else
        project_path(project)
      end
    end
  end
end
