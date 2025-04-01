class ApplicationController < ActionController::Base
  skip_forgery_protection
  include Pagy::Backend

  def default_url_options(options = {})
    Rails.env.production? ? { :protocol => "https" }.merge(options) : options
  end

  private

  def range
    (params[:range].presence || 360).to_i
  end

  def period
    case range
    when 0..30
      (params[:period].presence || 'day').to_sym
    when 31..90
      (params[:period].presence || 'week').to_sym
    when 91..366
      (params[:period].presence || 'month').to_sym
    else
      (params[:period].presence || 'year').to_sym
    end
  end

  def timescale
    case period
    when :day
      30 # 1 month
    when :week
      7*12 # 12 weeks
    when :month
      366 # 12 months
    when :year
      365*3 # 3 years
    end
  end

  def interval
    case period
    when :day
      1.hour
    when :week
      1.day
    when :month
      1.day
    when :year
      1.month
    end
  end

  def start_date
    (params[:start_date].presence && params[:start_date].to_datetime) || default_start_date
  end

  def end_date
    (params[:end_date].presence && params[:end_date].to_datetime) || default_end_date
  end

  helper_method :default_end_date
  def default_end_date    
    case period
    when :day
      1.day.ago.end_of_day
    when :week
      1.week.ago.end_of_week
    when :month
      1.month.ago.end_of_month
    when :year
      1.year.ago.end_of_year
    end
  end

  helper_method :default_start_date
  def default_start_date
    case period
    when :day
      1.day.ago.beginning_of_day
    when :week
      1.week.ago.beginning_of_week
    when :month
      1.month.ago.beginning_of_month
    when :year
      1.year.ago.beginning_of_year
    end
  end
end
