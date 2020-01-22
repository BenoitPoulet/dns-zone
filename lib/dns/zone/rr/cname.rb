# `CNAME` resource record.
#
# RFC 1035
class DNS::Zone::RR::CNAME < DNS::Zone::RR::Record

  attr_accessor :domainname

  def dump
    parts = general_prefix
    parts << domainname
    parts.join(' ')
  end

  def load(string, options = {})
    rdata = load_general_and_get_rdata(string, options)
    return nil unless rdata
    @domainname = rdata
    if !@domainname.end_with?(".")
      if options[:last_origin] == '@'
        @domainname = "#{@domainname}.#{options[:default_origin]}"
      else
        @domainname = "#{@domainname}.#{options[:last_origin]}"
      end
    end
    self
  end

end
