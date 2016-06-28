#!/usr/bin/env ruby

require 'rubygems'
require 'commander'
require 'rbtagger'
require 'ffi/hunspell'
require 'english'
require 'open-uri'
require 'open_uri_redirections'
require 'nokogiri'
require 'json'
require 'yaml'

class Option
  def initialize
    @enabled = Array.new
  end

  attr_accessor :listing
  attr_accessor :enabled
  attr_accessor :default
end

class OptionFormat < Option
  def initialize
    super
    @listing = {:text => 'Plain text separated by a new line.', :csv => 'Plain text separated by commas.', :json => 'Object representation conforming to http://www.json.org/', :yaml => 'Object representation conforming to http://yaml.org/'}
    @default = :text
  end
end

class OptionModifiers < Option
  def initialize
    super
    @listing = {:CC => 'conjunction', :DT => 'determiner', :IN => 'preposition', :JJ => 'adjective', :NN => 'noun', :NNS => 'noun plural', :NNP => 'noun proper', :NNPS => 'noun proper plural', :RB => 'adverb', :UH => 'interjection', :VB => 'verb', :VBD => 'verb past tense', :VBG => 'verb present participle', :VBN => 'verb past participle'}
    @default = [:JJ, :NN, :VBD]
  end

  def add(mod)
    @enabled << mod if @listing.include?(mod.intern)
  end
end

class LinkSources
  def initialize
    @links = Array.new
    @default = ['http://en.wikipedia.org/wiki/Special:Random', 'http://en.wikipedia.org/wiki/Special:Random', 'http://en.wikipedia.org/wiki/Special:Random', 'http://en.wikipedia.org/wiki/Special:Random']
  end

  attr_accessor :links
  attr_accessor :default

  def add(links)
    @links << links unless @links.include?(links)
  end

  def text
    @text ||= link_text
  end

  private

  def link_text
    @links = @default if @links.length == 0
    text = String.new

    for s in @links
      links = open(s, :allow_redirections => :safe) { |f| f.read }
      dom = Nokogiri.HTML(links)
      dom.css('head,script,style,code').map { |l| l.unlink }
      text += dom.text
    end

    text
  end
end

class Generator
  def initialize(links, modifiers)
    @links = links
    @modifiers = modifiers
    @separator = String.new
    @suggestions = Array.new
  end

  attr_writer :separator

  def suggest
    words = Array.new

    @modifiers.enabled.each { |m|
      types = tags.select { |k,v| v == m.to_s }
      types = types.keys
      words << types[rand(types.size - 1)]
    }

    words.join(@separator)
  end

  def suggestions(count)
    suggestions = Array.new
    i = j = 0

    while i < count
      j += 1
      s = suggest
      break if j > count * 2
      next if suggestions.include?(s)
      suggestions << s
      i += 1
    end

    suggestions
  end

  private

  def tags
    @tags ||= Hash[tagger.tag(link_text.join(' '))]
  end

  def tagger
    @tagger ||= Brill::Tagger.new
  end

  def dict
    @dict ||= FFI::Hunspell.dict('en_US')
  end

  def link_text
    text = @links.text.words
    text.reject! { |word| word.length < 4 }
    text.keep_if { |word| word =~ /^[a-z]+$/i }
    text.keep_if { |word| dict.check?(word) }
    text.map! { |word| word.downcase }
    text.uniq
  end
end

class Writer
  def initialize(links, modifiers)
    @links = links
    @modifiers = modifiers
  end

  def data(suggestions)
    @suggestions = suggestions
  end

  def write_as(format)
    case format
      when :json
        write_json
      when :yaml
        write_yaml
      when :csv
        write_csv
      else
        write_text
    end
  end

  private

  def write_text
    @suggestions.each { |line| puts line }
  end

  def write_csv
    @suggestions.map! { |r| sprintf '"%s"', r }
    puts @suggestions.join(',')
  end

  def write_yaml
    puts YAML::dump(suggestions_object)
  end

  def write_json
    puts JSON::generate(suggestions_object)
  end

  def suggestions_object
    result_object = Hash.new
    result_object['config'] = Hash.new
    result_object['config']['links'] = @links.links
    result_object['config']['modifiers'] = Array.new
    @modifiers.enabled.each { |m| result_object['config']['modifiers'] << m.to_s }
    result_object['suggestions'] = @suggestions

    result_object
  end
end

class Application
  include Commander::Methods

  def initialize
    @format = OptionFormat.new
    @modifiers = OptionModifiers.new
    @links = LinkSources.new
    @generator = Generator.new @links, @modifiers
    @writer = Writer.new @links, @modifiers
  end

  def run
    program :name, 'RENAM'
    program :version, '1.0.0'
    program :description, 'Utility to return a randomly generated list of possible "release names" using different links to create the dictionary of words used.'
    program :help, 'Authors', 'Rob Frawley 2nd <rmf@src.run>, Dan Corrigan <dfc@scribenet.com>'
    program :help, 'License', 'MIT License (https://rmf.mit-license.org)'

    command :suggest do |c|
      c.syntax = "renamr #{c.name} [options] -- [<links>]..."
      c.summary = 'Generate word combination suggestions.'
      c.description = 'Generate word combination suggestions by fetching passed url(s) and parsing their text contents for the set of words used.'

      c.example 'return two results using custom url', \
        "renamr #{c.name} --results 2 'https://wikipedia.org/LED'"
      c.example 'output 20 results as json using custom modifiers', \
        "renamr #{c.name} --results 20 --modifiers NN,JJ --format json"

      c.option '-r', '--results INT', Integer, 'Number of result entried to generate'
      c.option '-f', '--format STRING', String, 'Format of returned results'
      c.option '-F', '--list-formats', 'List available output formats'
      c.option '-m', '--modifiers ARRAY', Array, 'Modifiers for result generation as Penn Treebank tags'
      c.option '-M', '--list-modifiers', 'List available modifier tags'
      c.option '-s', '--separator STRING', String, 'Value placed between modifier tags'

      c.action do |args, options|
        options.default \
          :verbose => false,
          :results => 1,
          :separator => '-',
          :format => 'text',
          :modifiers => @modifiers.default

        parse_opts options
        parse_args args

        data = @generator.suggestions options.results
        say_warning 'Not enough input variance to generate requested number of results!' if data.length < options.results

        @writer.data data
        @writer.write_as @format.enabled
      end
    end

    default_command :suggest

    run!

  end

  private

  def say_formats
    puts "TYPE  DESCRIPTION\n----  -----------"
    @format.listing.each { |format, desc| puts sprintf('%4s  %s', format, desc) }
    exit
  end

  def say_modifiers
    puts "TYPE  DESCRIPTION\n----  -----------"
    @modifiers.listing.each { |modifier, desc| puts sprintf('%4s  %s', modifier, desc) }
    exit
  end

  def parse_opts(o)
    say_formats if o.list_formats
    say_modifiers if o.list_modifiers

    @generator.separator = o.separator

    @format.enabled = o.format.downcase.intern
    unless @format.listing.include?(@format.enabled)
      say_error "Error: Invalid option provided as output format: #{o.format}"
      say_formats
    end

    @modifiers.enabled = @modifiers.default if o.modifiers.length == 0
    o.modifiers.each do |m|
      unless @modifiers.listing.include?(m.upcase.intern)
        say_error "Error: Invalid option provided as modifier: #{m}"
        say_modifiers
      end
      @modifiers.add(m.upcase.intern)
    end
  end

  def parse_args(args)
    args.each { |a| @links.add(a) }
    @links.links = @links.default if @links.links.length == 0
  end
end

Application.new.run if $0 == __FILE__
