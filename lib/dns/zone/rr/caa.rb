# `CAA` resource record.
#
# RFC 6844
class DNS::Zone::RR::CAA < DNS::Zone::RR::Record

  REGEX_CAA_RDATA = %r{
    (?<flag>\d+)\s*
    (?<tag>\w+)\s*
    (?<value>#{DNS::Zone::RR::REGEX_CHARACTER_STRING})\s*
  }mx

  attr_accessor :flag, :tag, :value

  def dump
    parts = general_prefix
    parts << flag
    parts << tag
    parts << value
    parts.join(' ')
  end

  def load(string, options = {})
    rdata = load_general_and_get_rdata(string, options)
    return nil unless rdata

    captures = rdata.match(REGEX_CAA_RDATA)
    return nil unless captures

    @flag = captures[:flag].to_i
    @tag = captures[:tag]
    @value = captures[:value]
    self
  end

end
