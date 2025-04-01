class ChartsController < ApplicationController
  def transactions
    if params[:collective_slugs].present?
      @collectives = Collective.where(slug: params[:collective_slugs].split(',')).limit(20)
      @transactions = Transaction.where(collective: @collectives)
    else
      @transactions = Transaction.opensource
    end

    render json: Collective.transaction_chart_data(@transactions, kind: params[:chart], period: period, range: range, start_date: start_date, end_date: end_date)
  end

  def issues
    if params[:collective_slugs].present?
      @collectives = Collective.where(slug: params[:collective_slugs].split(',')).limit(20)
      @issues = Issue.where(project_id: Project.where(collective: @collectives).pluck(:id))
    elsif params[:project_ids].present?
      @issues = Issue.where(project_id: params[:project_ids].split(','))
    else
      @issues = Issue.all
    end

    @issues = @issues.human if params[:exclude_bots] == 'true'
    @issues = @issues.bot if params[:only_bots] == 'true'

    render json: Collective.issue_chart_data(@issues, kind: params[:chart], period: period, range: range, start_date: start_date, end_date: end_date)
  end

  def commits
    if params[:collective_slugs].present?
      @collectives = Collective.where(slug: params[:collective_slugs].split(',')).limit(20)
      @commits = Commit.where(project_id: Project.where(collective: @collectives).pluck(:id))
    elsif params[:project_ids].present?
      @commits = Commit.where(project_id: params[:project_ids].split(','))
    else
      @commits = Commit.all
    end

    render json: Collective.commit_chart_data(@commits, kind: params[:chart], period: period, range: range, start_date: start_date, end_date: end_date)
  end

  def tags
    if params[:collective_slugs].present?
      @collectives = Collective.where(slug: params[:collective_slugs].split(',')).limit(20)
      @tags = Tag.where(project_id: Project.where(collective: @collectives).pluck(:id))
    elsif params[:project_ids].present?
      @tags = Tag.where(project_id: params[:project_ids].split(','))
    else
      @tags = Tag.all
    end

    render json: Collective.tag_chart_data(@tags, kind: params[:chart], period: period, range: range, start_date: start_date, end_date: end_date)
  end
end