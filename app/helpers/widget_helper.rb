module WidgetHelper
  def small_widget(title, current_value, previous_value, increase_good: true, symbol: nil)
    content_tag(:div, class: "card well p-3 border-0") do
      content_tag(:div, class: "card-body") do
        content_tag(:h5, title, class: "card-title small") +
        content_tag(:div, class: "stat-card mb-2") do
          content_tag(:div, class: "stat-card-body") do
            stat_class = stat_class_for(current_value, previous_value)

            content_tag(:span, class: stat_class) do
              safe_join([
                "#{current_value}#{symbol}".strip + ' ',
                caret_icon_for(current_value, previous_value)
              ])
            end +
            content_tag(:span, "#{previous_value}#{symbol} last period", class: "stat-card-text")
          end
        end
      end
    end
  end

  private

  def stat_class_for(current_value, previous_value)
    "stat-card-title stat-card-title--large " +
      if current_value > previous_value
        "stat-card-number-positive"
      elsif current_value < previous_value
        "stat-card-number-negative"
      else
        "stat-card-number-neutral"
      end
  end

  def caret_direction_for(current_value, previous_value)
    if current_value > previous_value
      'caret-up-fill'
    elsif current_value < previous_value
      'caret-down-fill'
    end
  end

  def caret_icon_for(current_value, previous_value)
    direction = caret_direction_for(current_value, previous_value)
    if direction
      bootstrap_icon(direction, width: 18, height: 18, class: 'flex-shrink-0')
    else
      content_tag(:span, "-", class: "extra-bold")
    end
  end
end