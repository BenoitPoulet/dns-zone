require 'dns/zone/test_case'

class RR_CAA_Test < DNS::Zone::TestCase

  def test_build_rr__caa
    rr = DNS::Zone::RR::CAA.new
    rr.flag = 0
    rr.tag = 'issue'
    rr.value = '"letsencrypt.org"'
    assert_equal '@ IN CAA 0 issue "letsencrypt.org"', rr.dump
  end

  def test_load_rr__caa
    rr = DNS::Zone::RR::CAA.new.load('@ IN CAA 0 issue "letsencrypt.org"')
    assert_equal '@', rr.label
    assert_equal 'CAA', rr.type
    assert_equal 0, rr.flag
    assert_equal 'issue', rr.tag
    assert_equal '"letsencrypt.org"', rr.value
  end

  def test_load_rr__caa_iodef
    rr = DNS::Zone::RR::CAA.new.load('@ IN CAA 0 iodef "mailto:caa-notify@lividpenguin.com"')
    assert_equal '@', rr.label
    assert_equal 'CAA', rr.type
    assert_equal 0, rr.flag
    assert_equal 'iodef', rr.tag
    assert_equal '"mailto:caa-notify@lividpenguin.com"', rr.value
  end

end
