# `A` resource record.
#
# RFC 1035
class DNS::Zone::RR::TXT < DNS::Zone::RR::Record

  attr_accessor :text

  def dump
    parts = general_prefix
    parts << quote_text(text)
    parts.join(' ')
  end

  def load(string, options = {})
    rdata = load_general_and_get_rdata(string, options)
    return nil unless rdata
    # extract text from within quotes; allow multiple quoted strings; ignore escaped quotes
    @text = rdata.scan(/"#{DNS::Zone::RR::REGEX_STRING}"/).join
    self
  end

  protected

  # Quotes the given text, e.g. the content of a TXT or SPF record.
  # Respects the rule that a single string may contain at most 255 chars, but
  # multiple strings can be used to produce longer content. See also RFC 4408,
  # section 3.1.3.
  #
  # @param text [String] the (potentially long) text
  # @return [String] the quoted string or, if needed, several quoted strings
  def quote_text(text)
    text.chars.each_slice(200).map(&:join).map { |chunk| %Q{"#{chunk}"} }.join(' ')
  end

end
