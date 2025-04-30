module WidgetHelper

  def small_widget(title, current_value, previous_value, increase_good: true, symbol: nil, currency: false)
    stat_card_widget(
      title,
      current_value,
      previous_value,
      increase_good: increase_good,
      symbol: symbol,
      title_class: "small",
      card_class: "",
      stat_size: "small",
      currency: currency
    )
  end

  def stat_card_widget(title, current_value, previous_value, increase_good: true, symbol: nil, title_class:, card_class: "", stat_size: "large", currency: false, &block)
    content_tag(:div, class: "card #{card_class} well p-3 border-0") do
      content_tag(:div, class: "card-body") do
        content_tag(:h5, title, class: "card-title "+ title_class) +
        content_tag(:div, class: "stat-card mb-2") do
          content_tag(:div, class: "stat-card-body") do
            stat_class = "stat-card-title stat-card-title--#{stat_size} #{stat_class_for(current_value, previous_value, increase_good)}"

            content_tag(:span, class: stat_class) do
              safe_join([
                "#{currency ? number_to_currency(current_value, unit: symbol || '$') : "#{number_with_delimiter(current_value)}#{symbol}"}".strip + ' ',
                (previous_value.nil? ? nil : caret_icon_for(current_value, previous_value))
              ])
            end +
            (previous_value.nil? ? "".html_safe : content_tag(:span, "#{currency ? number_to_currency(previous_value, unit: symbol || '$') : "#{number_with_delimiter(previous_value)}#{symbol}"} last period", class: "stat-card-text"))
          end
        end +
        (block_given? ? capture(&block) : "".html_safe)
      end
    end
  end

  def display_link(url)
    url.gsub(/https?:\/\//, '').gsub(/www\./, '')
  end

  def stat_class_for(current_value, previous_value, increase_good = true)
    return "stat-card-number  stat-card-number-neutral" if previous_value.nil? || increase_good.nil?
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

  def caret_direction_for(current_value, previous_value)
    return nil if previous_value.nil?
    return nil if current_value == previous_value

    positive = current_value > previous_value
    if positive 
      'caret-up-fill'
    else
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

  def domain_icons
    {
      'github.com' => 'github',
      'gitlab.com' => 'gitlab',
      'bitbucket.org' => 'git',
      'codeberg.org' => 'git',
      'sourcehut.org' => 'git',
      'gitea.com' => 'git',
      'gogs.io' => 'git',
      'salsa.debian.org' => 'git',
      'launchpad.net' => 'git',
      'framagit.org' => 'git',
      'git.disroot.org' => 'git',
      'gitlab.gnome.org' => 'git',
      'tildegit.org' => 'git',
      'sourceforge.net' => 'sourceforge'
    }
  end

  def funding_domains
    [
      "opencollective.com",
      "ko-fi.com",
      "liberapay.com",
      "patreon.com",
      "otechie.com",
      "issuehunt.io",
      "thanks.dev",
      "communitybridge.org",
      "tidelift.com",
      "buymeacoffee.com",
      "paypal.com",
      "paypal.me",
      "givebutter.com",
      "polar.sh"
    ]
  end

  def registry_domains
    [
      "anaconda.org",
      "bioconductor.org",
      "bower.io",
      "cocoapods.org",
      "conda-forge.org",
      "cran.r-project.org",
      "crates.io",
      "deno.land",
      "elpa.gnu.org",
      "elpa.nongnu.org",
      "forge.puppet.com",
      "formulae.brew.sh",
      "hackage.haskell.org",
      "hex.pm",
      "hub.docker.com",
      "juliahub.com",
      "metacpan.org",
      "package.elm-lang.org",
      "packages.spack.io",
      "packagist.org",
      "pkg.adelielinux.org",
      "pkgs.alpinelinux.org",
      "pkgs.postmarketos.org",
      "pkgs.racket-lang.org",
      "proxy.golang.org",
      "pub.dev",
      "pypi.org",
      "registry.npmjs.org",
      "repo.clojars.org",
      "repo1.maven.org",
      "rubygems.org",
      "swiftpackageindex.com",
      "vcpkg.io",
      "www.nuget.org"
    ]
  end

  def link_icon(url)
    # special case for github.com/sponsors
    return 'wallet' if url.include?('github.com/sponsors')
    
    domain = URI.parse(url).host
    return 'wallet' if funding_domains.include?(domain)
    return 'boxes' if registry_domains.include?(domain)
    domain_icons[domain] || 'link-45deg'
  rescue
    'link-45deg'
  end
end