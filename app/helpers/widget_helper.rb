module WidgetHelper

  def small_widget(title, current_value, previous_value, increase_good: true, symbol: nil)
    stat_card_widget(
      title,
      current_value,
      previous_value,
      increase_good: increase_good,
      symbol: symbol,
      title_class: "small",
      card_class: "",
      stat_size: "small"
    )
  end

  def stat_card_widget(title, current_value, previous_value, increase_good: true, symbol:, title_class:, card_class: "", stat_size: "large", &block)
    content_tag(:div, class: "card #{card_class} well p-3 border-0") do
      content_tag(:div, class: "card-body") do
        content_tag(:h5, title, class: "card-title "+ title_class) +
        content_tag(:div, class: "stat-card mb-2") do
          content_tag(:div, class: "stat-card-body") do
            stat_class = "stat-card-title stat-card-title--#{stat_size} #{stat_class_for(current_value, previous_value, increase_good)}"

            content_tag(:span, class: stat_class) do
              safe_join([
                "#{number_with_delimiter(current_value)}#{symbol}".strip + ' ',
                caret_icon_for(current_value, previous_value, increase_good)
              ])
            end +
            content_tag(:span, "#{number_with_delimiter(previous_value)}#{symbol} last period", class: "stat-card-text")
          end
        end +
        (block_given? ? capture(&block) : "".html_safe)
      end
    end
  end

  def stat_class_for(current_value, previous_value, increase_good = true)
    positive = current_value > previous_value
    neutral = current_value == previous_value

    "stat-card-number " +
      if neutral
        "stat-card-number-neutral"
      elsif (positive && increase_good) || (!positive && !increase_good)
        "stat-card-number-positive"
      else
        "stat-card-number-negative"
      end
  end

  def caret_direction_for(current_value, previous_value, increase_good = true)
    return nil if current_value == previous_value

    positive = current_value > previous_value
    if (positive && increase_good) || (!positive && !increase_good)
      'caret-up-fill'
    else
      'caret-down-fill'
    end
  end

  def caret_icon_for(current_value, previous_value, increase_good = true)
    direction = caret_direction_for(current_value, previous_value, increase_good)
    if direction
      bootstrap_icon(direction, width: 18, height: 18, class: 'flex-shrink-0')
    else
      content_tag(:span, "-", class: "extra-bold")
    end
  end
end