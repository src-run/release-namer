#!/usr/bin/env ruby

##
## Release Namer
##
## @license: MIT License
## @author : Dan Corrigan <github.com/dcorrigan>
##

require 'optparse'
require 'engtagger'
require 'uri'
require 'open-uri'
require 'nokogiri'

class ReleaseNamer

  VERSION = '1.2.0'
  LICENSE = 'MIT'
  AUTHORS = [
      'Rob Frawley 2nd <rmf@src.run>',
      'Dan Corrigan <dcorrigan@scribenet.com>'
  ]

  TAG_METHOD_MAP = {
    get_proper_nouns: %w(NNP),
    get_nouns: %w(NN),
    get_verbs: %w(VB VBD VBG PART VBP VBZ),
    get_infinitive_verbs: %w(VB),
    get_past_tense_verbs: %w(VBD),
    get_gerund_verbs: %w(VBG),
    get_passive_verbs: %(PART),
    get_base_present_verbs: %w(VBP),
    get_present_verbs: %w(VBZ),
    get_adjectives: %w(JJ),
    get_comparative_adjectives: %w(JJR),
    get_superlative_adjectives: %w(JJS),
    get_adverbs: %w(RB RBR RBS RP),
    get_interrogatives: %w(WRB WDT WP WPS),
    get_conjunctions: %w(CC IN)
  }

  def initialize(uris, format)0
    @words = (uris.map { |u| get_tagger.add_tags(uri_to_txt(u)) }).join(' ')
    @calls = get_pos_methods format
  end

  def suggestion
    @calls.map { |c| pick_word(get_word_list(c)) }.join('-')
  end

  private

  def get_pos_methods(types)
    types.map { |t| resolve_tag_method t }.reject{ |m| m == nil }
  end

  def resolve_tag_method(tag)
    for i, v in TAG_METHOD_MAP
      if v.include?(tag)
        return i.to_s
      end
    end

    nil
  end

  def uri_to_txt(uri)
    src_to_dom(open(uri, "User-Agent" => "Ruby/#{RUBY_VERSION}") { |f| f.read }).text
  end

  def src_to_dom(src)
    dom = Nokogiri.HTML(src)
    dom.css('head,script,style,code').map { |l|
      l.unlink
    }
    dom
  end

  def get_word_list(type)
    get_tagger.send(type, @words).map { |i, v| String.new(i) }
  end

  def get_tagger
    @tagger ||= EngTagger.new
  end

  def pick_word(words)
    cleanup_word(pick_random_word(cleanup_word_list(words)))
  end

  def pick_random_word(words)
    words[rand(words.size - 1)]
  end

  def cleanup_word_list(list)
    list.reject { |x| x.match('[^a-zA-Z-]') }
  end

  def cleanup_word(word)
    word.downcase
  end

end

class ReleaseNamerCliConfig

  DEFAULT_URIS = [
      'http://en.wikipedia.org/wiki/Special:Random',
  ]

  def initialize
    options = {
        :count => 1,
        :format => Array.new,
        :uris => Array.new,
    }

    parser = OptionParser.new do|o|
      o.banner =
          "Usage:\n"+
          "    release-namer [options] [--] [<url-1> <url-2> ...]\n\n"+
          "Example:\n"+
          "    release-namer --count=5 --format=JJ --format=VBD --format=NN\n"+
          "    release-namer --count=9 'https://en.wikipedia.org/wiki/Computer_science' 'https://en.wikipedia.org/wiki/Art'\n\n"+
          "Arguments:\n"+
          "    Any number of urls can be provided as arguments, the source text of which will be used as the pool of\n"+
          "    random words for the generator. This allows you to specify urls with content that is targeted within\n"+
          "    the \"focus\" you'd like the generator to draw from. When specifying Wikipedia pages, instead of the\n"+
          "    complete url, you may specify only the Wikipedia page name. If no url arguments are provided the default\n"+
          "    url(s) used are: #{DEFAULT_URIS}\n\n"+
          "Options:"

      o.on('-c', '--count INT', 'Number of generated name results to create and output.') do |count|
        options[:count] = count.to_i
      end

      o.on('-f', '--format STR', 'Define a custom format for the generated names using parts of speech tags.') do |format|
        options[:format].push format
      end

      o.on('-h', '--help', 'Display this help message.') do
        puts o
        exit 255
      end

      o.on('-t', '--help-tags', 'Display the supported parts of speech tags for the "--format" option.') do
        write_tag_list
        exit 255
      end

      o.on('-v', '--version', 'Show script version string.') do
        printf "Project Release Namer v%s (%s License) [%s]\n", ReleaseNamer::VERSION, ReleaseNamer::LICENSE, ReleaseNamer::AUTHORS.join(', ')
        exit 0
      end
    end

    parser.parse!

    options[:uris] = parse_uris(ARGV)
    options[:uris] = parse_uris(DEFAULT_URIS) if options[:uris].length == 0

    options[:count].times do |_x|
      puts get_release_namer(options).suggestion
    end
  end

  def get_release_namer(options)
    @namer ||= ReleaseNamer.new(options[:uris], options[:format].length == 0 ? %w(JJ NN) : options[:format])
  end

  def write_tag_list
    printf "TAG\tDESCRIPTION\n---\t-----------\n"
    EngTagger::TAGS.each { |t, d| write_tag_list_item(t) }
  end

  def write_tag_list_item(tag)
    printf "%s\t%s\n", tag.upcase, clean_and_format_tag_desc(EngTagger::explain_tag(tag))
  end

  def clean_and_format_tag_desc(desc)
    desc.split('_').collect(&:capitalize).join(' ')
  end

  def parse_uris(uris)
    uris.map{ |l| parse_uri_from_str(l) }
  end

  def parse_uri_from_str(str)
    uri = create_uri(str)
    uri = create_uri(sprintf('http://en.wikipedia.org/wiki/%s', str)) unless uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS)
    uri
  end

  def create_uri(uri)
    URI.parse(uri) rescue false
  end

end

ReleaseNamerCliConfig.new do |_n|
  puts _n.suggestion
end

## EOF
