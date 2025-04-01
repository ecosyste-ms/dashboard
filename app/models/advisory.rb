class Advisory < ApplicationRecord
  belongs_to :project

  def source
    source_kind
  end

  def to_s
    uuid
  end

  def ecosystems
    packages.map{|p| p['ecosystem'] }.uniq
  end

  def package_names
    packages.map{|p| p['package_name'] }.uniq
  end
end
