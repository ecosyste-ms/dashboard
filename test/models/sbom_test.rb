require "test_helper"

class SbomTest < ActiveSupport::TestCase
  def setup
    @cyclone_file = Rails.root.join("test", "fixtures", "files", "cyclone.json")
    @cyclone_raw = File.read(@cyclone_file)
    
    @spdx_file = Rails.root.join("test", "fixtures", "files", "octobox_spdx.json")
    @spdx_raw = File.read(@spdx_file)
  end

  test "should create sbom with cyclone dx raw data" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    assert sbom.persisted?
    assert_equal @cyclone_raw, sbom.raw
  end

  test "should convert cyclone dx sbom to syft format" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    
    sbom.convert
    
    assert_not_nil sbom.converted
    assert sbom.converted.present?
  end

  test "should parse converted json" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    sbom.convert
    
    json = sbom.converted_json
    assert_not_nil json
    assert json.is_a?(Hash)
    assert json.key?("artifacts")
  end

  test "should extract artifacts from converted sbom" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    sbom.convert
    
    artifacts = sbom.artifacts
    assert artifacts.is_a?(Array)
    assert artifacts.length > 0
  end

  test "should extract package urls from artifacts" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    sbom.convert
    
    purls = sbom.packageurls
    assert purls.is_a?(Array)
    assert purls.length > 0
    
    purls.each do |purl|
      assert purl.respond_to?(:to_s)
      assert purl.to_s.start_with?("pkg:")
    end
  end

  test "should extract specific gem purls from cyclone dx sbom" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    sbom.convert
    
    purls = sbom.packageurls
    purl_strings = purls.map(&:to_s)
    
    assert purl_strings.any? { |p| p.include?("pkg:gem/actioncable@") }
    assert purl_strings.any? { |p| p.include?("pkg:gem/activesupport@") }
    assert purl_strings.any? { |p| p.include?("pkg:gem/rails@") || p.include?("pkg:gem/actionpack@") }
  end

  test "should extract github action purls from cyclone dx sbom" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    sbom.convert
    
    purls = sbom.packageurls
    purl_strings = purls.map(&:to_s)
    
    assert purl_strings.any? { |p| p.include?("pkg:github/actions/checkout@") }
    assert purl_strings.any? { |p| p.include?("pkg:github/actions/setup-node@") }
  end

  test "should handle invalid converted json gracefully" do
    sbom = Sbom.create!(raw: @cyclone_raw, converted: "invalid json")
    
    assert_nil sbom.converted_json
    assert_equal [], sbom.artifacts
    assert_equal [], sbom.packageurls
  end

  test "should return empty arrays when no converted data exists" do
    sbom = Sbom.create!(raw: @cyclone_raw)
    
    assert_equal [], sbom.artifacts
    assert_equal [], sbom.packageurls
  end

  test "should create sbom with spdx raw data" do
    sbom = Sbom.create!(raw: @spdx_raw)
    assert sbom.persisted?
    assert_equal @spdx_raw, sbom.raw
  end

  test "should convert spdx sbom to syft format" do
    sbom = Sbom.create!(raw: @spdx_raw)
    
    sbom.convert
    
    assert_not_nil sbom.converted
    assert sbom.converted.present?
  end

  test "should parse spdx converted json" do
    sbom = Sbom.create!(raw: @spdx_raw)
    sbom.convert
    
    json = sbom.converted_json
    assert_not_nil json
    assert json.is_a?(Hash)
    assert json.key?("artifacts")
  end

  test "should extract artifacts from spdx converted sbom" do
    sbom = Sbom.create!(raw: @spdx_raw)
    sbom.convert
    
    artifacts = sbom.artifacts
    assert artifacts.is_a?(Array)
    assert artifacts.length > 0
  end

  test "should extract package urls from spdx artifacts" do
    sbom = Sbom.create!(raw: @spdx_raw)
    sbom.convert
    
    purls = sbom.packageurls
    assert purls.is_a?(Array)
    assert purls.length > 0
    
    purls.each do |purl|
      assert purl.respond_to?(:to_s)
      assert purl.to_s.start_with?("pkg:")
    end
  end

  test "should extract specific gem purls from spdx sbom" do
    sbom = Sbom.create!(raw: @spdx_raw)
    sbom.convert
    
    purls = sbom.packageurls
    purl_strings = purls.map(&:to_s)
    
    assert purl_strings.any? { |p| p.include?("pkg:gem/actioncable@") }
    assert purl_strings.any? { |p| p.include?("pkg:gem/activesupport@") }
    assert purl_strings.any? { |p| p.include?("pkg:gem/rails@") }
    assert purl_strings.any? { |p| p.include?("pkg:gem/chronic_duration@") }
    assert purl_strings.any? { |p| p.include?("pkg:gem/faraday@") }
  end


end
