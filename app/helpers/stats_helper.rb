module StatsHelper

  def render_stats(method, title:, icon:, range: nil, collective_slugs: nil, project_ids: nil)
    range = params[:range].try(:to_i).presence || @range.presence|| 30
    collective_slugs = params[:collective_slugs].presence || @collective.try(:slug)
    project_ids = params[:project_ids].presence || @project.try(:id)

    this_period, last_period = Collective.send(method, collective_slugs: collective_slugs, project_ids: project_ids, range: range)
    render partial: 'collectives/stat', locals: {icon: icon, title: title, this_period: this_period, last_period: last_period}
  end

  def stat_this_period(method, collective_slugs: nil, project_ids: nil, start_date: nil, end_date: nil)
    start_date ||= @start_date.presence || params[:start_date].presence || default_start_date
    end_date ||= @end_date.presence || params[:end_date].presence || default_end_date
    collective_slugs = params[:collective_slugs].presence || @collective.try(:slug)
    project_ids = params[:project_ids].presence || @project.try(:id)

    this_period, last_period = Collective.send(method, collective_slugs: collective_slugs, project_ids: project_ids, start_date: start_date, end_date: end_date)
    this_period
  end

  def issue_pie_chart(chart, title, collective_slugs: nil, project_ids: nil, start_date: nil, end_date: nil)
    start_date ||= @start_date.presence || params[:start_date].presence || default_start_date
    end_date ||= @end_date.presence || params[:end_date].presence || default_end_date
    collective_slugs = params[:collective_slugs].presence || @collective.try(:slug)
    project_ids = params[:project_ids].presence || @project.try(:id)

    pie_chart issues_chart_path(collective_slugs: collective_slugs, project_ids: project_ids, chart: chart, start_date: @start_date, end_date: @end_date), title: title, donut: true, legend: 'left', thousands: ","
  end

  def commit_pie_chart(chart, title, collective_slugs: nil, project_ids: nil, start_date: nil, end_date: nil)
    start_date ||= @start_date.presence || params[:start_date].presence || default_start_date
    end_date ||= @end_date.presence || params[:end_date].presence || default_end_date
    collective_slugs = params[:collective_slugs].presence || @collective.try(:slug)
    project_ids = params[:project_ids].presence || @project.try(:id)

    pie_chart commits_chart_path(collective_slugs: collective_slugs, project_ids: project_ids, chart: chart, start_date: @start_date, end_date: @end_date), title: title, donut: true, legend: 'left', thousands: ","
  end

  def transaction_pie_chart(chart, title, collective_slugs: nil, project_ids: nil, start_date: nil, end_date: nil)
    start_date ||= @start_date.presence || params[:start_date].presence || default_start_date
    end_date ||= @end_date.presence || params[:end_date].presence || default_end_date
    collective_slugs = params[:collective_slugs].presence || @collective.try(:slug)

    pie_chart transactions_chart_path(collective_slugs: collective_slugs, chart: chart, start_date: @start_date, end_date: @end_date), title: title, donut: true, legend: 'left', thousands: ",", zeros: true, prefix: "$"
  end

  def open_issues
    render_stats(:open_issues, title: 'New Issues', icon: 'issue-opened')
  end
end