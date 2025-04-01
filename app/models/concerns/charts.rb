module Charts
  extend ActiveSupport::Concern

  class_methods do

    def transaction_chart_data(scope, kind:, period:, range:, start_date:, end_date:)
      start_date = start_date.presence || range.days.ago
      end_date = end_date.presence || Date.today 

      scope = scope.created_after(start_date) if start_date.present?
      scope = scope.created_before(end_date) if end_date.present?

      scope = scope.not_host_fees #if kind != 'all_transactions'

      #Rails.cache.fetch("transaction_chart_data:#{kind}:#{period}:#{range}:#{start_date}:#{end_date}", expires_in: 1.day) do
        case kind
        when 'all_transactions'
          data = scope.group_by_period(period, :created_at).sum(:net_amount)
        when 'expenses'
          data = scope.expenses.group_by_period(period, :created_at).sum(:net_amount).map{|k,v| [k, -v]}.to_h
        when 'donations'
          data = scope.donations.group_by_period(period, :created_at).sum(:net_amount)
        when 'unique_donors'
          data = scope.donations.group_by_period(period, :created_at).distinct.count(:account)
        when 'unique_expenses'
          data = scope.expenses.group_by_period(period, :created_at).distinct.count(:account)
        when 'donations_and_expenses'
          data = [
            {name: 'Donations', data: scope.donations.group_by_period(period, :created_at).sum(:net_amount)},
            {name: 'Expenses', data: scope.expenses.group_by_period(period, :created_at).sum(:net_amount).map{|k,v| [k, -v]}},
            ]
        when 'unique_donors_and_spenders'
          data = [
            {name: 'Donors', data: scope.donations.group_by_period(period, :created_at).distinct.count(:account)},
            {name: 'Spenders', data: scope.expenses.group_by_period(period, :created_at).distinct.count(:account)}
            ]
        when 'new_collectives'
          scope = Collective.opensource
          scope = scope.where('collective_created_at >= ?', start_date) if start_date.present?
          scope = scope.where('collective_created_at <= ?', end_date) if end_date.present?

          data = scope.group_by_period(period, :collective_created_at).count
        when 'donor_pie'
          limit = 10
          all = scope.donations.group(:account).sum(:net_amount).sort_by{|k,v| -v}.to_h
          top = all.first(limit).to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'spenders_pie'
          limit = 10
          all = scope.expenses.group(:account).sum(:net_amount).sort_by{|k,v| v}.to_h
          top = all.first(limit).to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'expenses_pie'
          limit = 10
          all = scope.expenses.group(:transaction_expense_type).sum(:net_amount).sort_by{|k,v| v}.to_h
          top = all.first(limit).to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'transaction_kind_pie'
          limit = 10
          all = scope.group(:transaction_kind).sum(:net_amount).sort_by{|k,v| -v}.to_h
          top = all.first(limit).to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        end
        data
      #end
    end

    def issue_chart_data(scope, kind:, period:, range:, start_date:, end_date:)
      start_date = start_date.presence || range.days.ago
      end_date = end_date.presence || Date.today 

      scope = scope.created_after(start_date) if start_date.present?
      scope = scope.created_before(end_date) if end_date.present?
      
      #data = Rails.cache.fetch("issue_chart_data:#{kind}:#{period}:#{range}:#{start_date}:#{end_date}", expires_in: 1.day) do
        case kind
        when 'issues_opened'
          data = scope.issue.group_by_period(period, :created_at).count
        when 'issues_closed'
          data = scope.issue.closed.group_by_period(period, :closed_at).count
        when 'issue_authors'
          data = scope.issue.group_by_period(period, :created_at).distinct.count(:user)
        when 'issue_average_time_to_close'
          data = scope.issue.closed.group_by_period(period, :closed_at).average(:time_to_close)
          data.update(data){ |_,v| v.to_f.seconds.in_days.round(1) }
        when 'pull_requests_opened'
          data = scope.pull_request.group_by_period(period, :created_at).count
        when 'pull_requests_closed'
          data = scope.pull_request.group_by_period(period, :closed_at).count
        when 'pull_requests_merged'
          data = scope.pull_request.merged.group_by_period(period, :merged_at).count
        when 'pull_requests_not_merged'
          data = scope.pull_request.not_merged.group_by_period(period, :closed_at).count
        when 'pull_request_authors'
          data = scope.pull_request.group_by_period(period, :created_at).distinct.count(:user)
        when 'pull_request_average_time_to_close'
          data = scope.pull_request.closed.group_by_period(period, :closed_at).average(:time_to_close)
          data.update(data){ |_,v| v.to_f.seconds.in_days.round(1) }
        when 'pull_request_average_time_to_merge'
          data = scope.pull_request.merged.group_by_period(period, :merged_at).average(:time_to_close)
          data.update(data){ |_,v| v.to_f.seconds.in_days.round(1) }
        when 'maintainers'
          data = scope.maintainers.group_by_period(period, :created_at).distinct.count(:user)

        when 'issues_and_pull_requests_pie_by_project'
          limit = 10
          all = scope.joins(:project).group('projects.url').count
          top = all.first(limit).sort_by{|k,v| -v}.to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'issues_and_pull_requests_pie_by_contributor'
          limit = 10
          all = scope.group(:user).count
          top = all.first(limit).sort_by{|k,v| -v}.to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'contributor_roles_pie'
          limit = 10
          all = scope.group(:author_association).count
          top = all.first(limit).sort_by{|k,v| -v}.to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        end
      
        ## TODO no data for these yet
        # Number of issue comments
        # Average number of comments per issue
        # Number of pull request comments
        # Average number of comments per pull request
        # Average time to first issue response
        # Average time to first pull request response
        data
      #end
    end

    def commit_chart_data(scope, kind:, period:, range:, start_date:, end_date:)
      start_date = start_date.presence || range.days.ago
      end_date = end_date.presence || Date.today 

      scope = scope.created_after(start_date) if start_date.present?
      scope = scope.created_before(end_date) if end_date.present?
      
      #data = Rails.cache.fetch("commit_chart_data:#{kind}:#{period}:#{range}:#{start_date}:#{end_date}", expires_in: 1.day) do
        case kind
        when 'commits'
          data = scope.group_by_period(period, :timestamp).count
        when 'merge_commits'
          data = scope.merges.group_by_period(period, :timestamp).count
        when 'commit_authors'
          data = scope.group_by_period(period, :timestamp).distinct.count(:author)
        when 'commit_committers'
          data = scope.group_by_period(period, :timestamp).distinct.count(:committer)
        when 'project_commits_pie'
          limit = 10
          all = scope.joins(:project).group('projects.url').count
          top = all.first(limit).sort_by{|k,v| -v}.to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'commit_authors_pie'
          limit = 10
          all = scope.group(:author).count
          top = all.first(limit).sort_by{|k,v| -v}.to_h
          if all.length > limit
            others = all.except(*top.keys).values.sum
            data = top.merge({'Others' => others})
          else
            data = top
          end
        when 'changes_pie'
          additions = scope.sum(:additions)
          deletions = scope.sum(:deletions)
          data = { 'Additions' => additions, 'Deletions' => deletions }
        end
        data
      #end
    end

    def tag_chart_data(scope, kind:, period:, range:, start_date:, end_date:)
      start_date = start_date.presence || range.days.ago
      end_date = end_date.presence || Date.today 

      scope = scope.created_after(start_date) if start_date.present?
      scope = scope.created_before(end_date) if end_date.present?
      
      #data = Rails.cache.fetch("tag_chart_data:#{kind}:#{period}:#{range}:#{start_date}:#{end_date}", expires_in: 1.day) do
        case kind
        when 'tags'
          data = scope.group_by_period(period, :published_at).count
        end
        data
      #end
    end
  end
end