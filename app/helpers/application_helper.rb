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

  def distance_of_time_in_words_if_present(time)
    return 'N/A' unless time
    distance_of_time_in_words(time)
  end

  def rounded_number_with_delimiter(number)
    return 0 unless number
    number_with_delimiter(number.round(2))
  end

  def render_issues_chart(name, max: @max, ytitle: nil)
    content_tag :div, class: 'chart-container py-4 my-4' do
      line_chart issues_chart_path(project_ids: @project.id, chart: name, period: @period, exclude_bots: @exclude_bots, range: @range, start_date: @start_date, end_date: @end_date), thousands: ",", title: name.humanize, max: max, ytitle: ytitle
    end
  end

  def render_commits_chart(name, max: @max, ytitle: nil)
    content_tag :div, class: 'chart-container py-4 my-4' do
      line_chart commits_chart_path(project_ids: @project, chart: name, period: @period, exclude_bots: @exclude_bots, range: @range, start_date: @start_date, end_date: @end_date), thousands: ",", title: name.humanize, max: max, ytitle: ytitle
    end
  end

  def render_collective_issues_chart(name, max: @max, ytitle: nil)
    content_tag :div, class: 'chart-container py-4 my-4' do
      line_chart issues_chart_path(collective_slugs: @collective.slug, chart: name, period: @period, exclude_bots: @exclude_bots, range: @range, start_date: @start_date, end_date: @end_date), thousands: ",", title: name.humanize, max: max, ytitle: ytitle
    end
  end

  def render_collective_commits_chart(name, max: @max, ytitle: nil)
    content_tag :div, class: 'chart-container py-4 my-4' do
      line_chart commits_chart_path(collective_slugs: @collective.slug, chart: name, period: @period, exclude_bots: @exclude_bots, range: @range, start_date: @start_date, end_date: @end_date), thousands: ",", title: name.humanize, max: max, ytitle: ytitle
    end
  end

  def render_batch_collective_issues_chart(name, max: @max, ytitle: nil)
    content_tag :div, class: 'chart-container py-4 my-4' do
      line_chart issues_chart_path(collective_slugs: params[:collective_slugs], chart: name, period: @period, exclude_bots: @exclude_bots, range: @range, start_date: @start_date, end_date: @end_date), thousands: ",", title: name.humanize, max: max, ytitle: ytitle
    end
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
end
