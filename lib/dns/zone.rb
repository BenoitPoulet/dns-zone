require 'dns/zone/rr'
require 'dns/zone/version'

# :nodoc:
module DNS

  # Represents a 'whole' zone of many resource records (RRs).
  #
  # This is also the primary namespace for the `dns-zone` gem.
  class Zone

    # The default $TTL (directive) of the zone.
    attr_accessor :ttl
    # The primary $ORIGIN (directive) of the zone.
    attr_accessor :origin
    # Array of all the zones RRs (including the SOA).
    attr_accessor :records

    # Create an empty instance of a DNS zone that you can drive programmatically.
    #
    # @api public
    def initialize
      @records = []
      soa = DNS::Zone::RR::SOA.new
      # set a couple of defaults on the SOA
      soa.serial = Time.now.utc.strftime("%Y%m%d01")    
      soa.refresh_ttl = '3h'
      soa.retry_ttl = '15m'
      soa.expiry_ttl = '4w'
      soa.minimum_ttl = '30m'
    end

    # Helper method to access the zones SOA RR.
    #
    # @api public
    def soa
      # return the first SOA we find in the records array.
      rr = @records.find { |record| record.type == "SOA" }
      return rr if rr
      # otherwise create a new SOA
      rr = DNS::Zone::RR::SOA.new
      rr.serial = Time.now.utc.strftime("%Y%m%d01")    
      rr.refresh_ttl = '3h'
      rr.retry_ttl = '15m'
      rr.expiry_ttl = '4w'
      rr.minimum_ttl = '30m'
      # store and return new SOA
      @records << rr
      return rr
    end

    # Generates output of the zone and its records.
    #
    # @api public
    def dump
      content = []

      @records.each do |rr|
        content << rr.dump
      end

      dump_directives << content.join("\n") << "\n"
    end

    # Generates pretty output of the zone and its records.
    #
    # @api public
    def dump_pretty
      content = []

      last_type = "SOA"
      sorted_records.each do |rr|
        content << '' if last_type != rr.type
        content << rr.dump
        last_type = rr.type
      end

      dump_directives << content.join("\n") << "\n"
    end

    # Load the provided zone file data into a new DNS::Zone object.
    # When $INCLUDE directives may be used in the given zone data, then it makes
    # sense to specify the include_callback argument. It receives the file name
    # to include and should return its content. By default, it resolves relative
    # file names with respect to the current working directory - but this is
    # probably not the location of the currently processed zone file.
    #
    # @api public
    def self.load(string, default_origin = "", include_callback = ->(filename) { File.read(filename) })
      # get entries
      entries = self.extract_entries(string)

      instance = self.new

      load_entries(entries, instance, include_callback, default_origin: default_origin)

      # use default_origin if we didn't see a ORIGIN directive in the zone
      if instance.origin.to_s.empty? && !default_origin.empty?
        instance.origin = default_origin
      end

      return instance
    end

    # Extract entries from a zone file that will be later parsed as RRs.
    #
    # @api private
    def self.extract_entries(string)
      # FROM RFC:
      #     The format of these files is a sequence of entries.  Entries are
      #     predominantly line-oriented, though parentheses can be used to continue
      #     a list of items across a line boundary, and text literals can contain
      #     CRLF within the text.  Any combination of tabs and spaces act as a
      #     delimiter between the separate items that make up an entry.  The end of
      #     any line in the master file can end with a comment.  The comment starts
      #     with a ";" (semicolon). 

      entries = []
      entry = ''

      parentheses_ref_count = 0

      string.lines.each do |line|
        # strip comments unless escaped
        # strip comments, unless its escaped.
        # skip semicolons within "quote segments" (TXT records)
        line = line.gsub(/((?<!\\);)(?=(?:[^"]|"[^"]*")*$).*/o, "").chomp

        next if line.gsub(/\s+/, '').empty?

        # append to entry line
        entry << line

        quotes = entry.count('"')
        has_quotes = quotes > 0

        if has_quotes
          character_strings = entry.scan(/("(?:[^"\\]+|\\.)*")/).join(' ')
          without = entry.gsub(/"((?:[^"\\]+|\\.)*)"/, '')
          parentheses_ref_count = without.count('(') - without.count(')')
        else
          parentheses_ref_count = entry.count('(') - entry.count(')')
        end

        # are parentheses balanced?
        if parentheses_ref_count == 0
          if has_quotes
            without.gsub!(/[()]/, '')
            without.gsub!(/[ ]{2,}/, '  ')
            #entries << (without + character_strings)
            entry = (without + character_strings)
          else
            entry.gsub!(/[()]/, '')
            entry.gsub!(/[ ]{2,}/, '  ')
            entry.gsub!(/[ ]+$/, '')
            #entries << entry
          end
          entries << entry
          entry = ''
        end

      end

      return entries
    end

    # Load the given extracted entries into an existing DNS::Zone object.
    #
    # @api private
    def self.load_entries(entries, instance, include_callback, options = {})
      options = { default_origin: '', last_origin: '', is_included: false }.merge(options)
      entries.each do |entry|
        # read in special statements like $TTL, $ORIGIN and $INCLUDE
        if entry =~ /\$(ORIGIN|TTL|INCLUDE)\s+(.+)/
          instance.ttl = $2 if $1 == 'TTL'
          if $1 == 'ORIGIN'
            unless options[:is_included]
              # we take the first $ORIGIN as "origin" (thus overriding "default_origin"), but only
              # if this $ORIGIN is directly in the zone file - i.e., not in an included file
              instance.origin ||= $2
              options[:origin] ||= $2
            end
            options[:last_origin] = $2
          end
          if $1 == 'INCLUDE'
            # when another file is included, we use the include_callback to obtain its content,
            # parse its entries, and work on it recursively
            # notes:
            # * the second argument to the $INCLUDE may specify an origin explicitly
            # * if no explicit origin is present, we pass the current "last_origin"
            # * the recursive call to load_entries() will not modify the current "options"
            included_file, included_origin = $2.split(' ')
            included_string = include_callback.call(included_file)
            included_entries = self.extract_entries(included_string)
            included_options = options.merge(last_origin: included_origin || options[:last_origin], is_included: true)
            load_entries(included_entries, instance, include_callback, included_options)
          end
          next
        end

        # parse each RR and create a Ruby object for it
        if entry =~ DNS::Zone::RR::REGEX_RR
          rec = DNS::Zone::RR.load(entry, options)
          next unless rec
          instance.records << rec
          options[:last_label] = rec.label
        end
      end

      return instance
    end

    private

    # Dumps the $ORIGIN and $TTL directives of this zone (for use by #dump and #dump_pretty).
    #
    # @api private
    def dump_directives
      content = ""
      content << "$ORIGIN #{origin}\n" unless origin.to_s.empty?
      content << "$TTL #{ttl}\n" unless ttl.to_s.empty?
      content
    end

    # Records sorted with more important types being at the top.
    #
    # @api private
    def sorted_records
      # pull out RRs we want to stick near the top
      top_rrs = {}
      top = %w{SOA NS MX SPF TXT}
      top.each { |t| top_rrs[t] = @records.select { |rr| rr.type == t } }

      remaining = @records.reject { |rr| top.include?(rr.type) }

      # sort remaining RRs by type, alphabeticly
      remaining.sort! { |a,b| a.type <=> b.type }

      top_rrs.values.flatten + remaining
    end


  end
end
