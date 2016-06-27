#!/usr/bin/env ruby

require 'rubygems'
require 'commander'
require 'engtagger'
require 'open-uri'
require 'open_uri_redirections'
require 'nokogiri'
require 'json'
require 'yaml'


class Opt
  def initialize
    @enabled = Array.new
  end

  attr_accessor :listing
  attr_accessor :enabled
  attr_accessor :default
end


class Formatter < Opt
  def initialize
    @listing = [:text, :csv, :json, :yaml]
    @default = :text
    super
  end

  def write(source, modifiers, results)
    result_hash = Hash.new
    result_hash['config'] = Hash.new
    result_hash['config']['sources'] = source.sources
    result_hash['config']['modifiers'] = Array.new
    modifiers.enabled.each do |m| result_hash['config']['modifiers'] << m.to_s end
    result_hash['suggestions'] = results

    case @enabled
      when :json
        puts JSON::generate(result_hash)
      when :yaml
        puts YAML::dump(result_hash)
      when :csv
        puts results[0] if results.length == 1
        puts results.join(',') if results.length > 1
      else
        results.each do |line|
          puts line
        end
    end
  end
end


class Modifiers < Opt
  def initialize
    @listing = [:conjunction, :determiner, :preposition, :adjective, :noun, :noun_proper, :adverb, :interjection, :verb_modal, :verb_infinitive, :verb_past]
    @default = [:adjective, :noun]
    @map = {:conjunction => :CC, :determiner => :DET, :preposition => :IN, :adjective => :JJ, :noun => :NN, :noun_proper => :NNP, :adverb => :RB, :interjection => :UH, :verb_modal => :MD, :verb_infinitive => :VB, :verb_past => :VBD}
    super
  end

  def map(name)
    @map[name.intern].to_s
  end

  def add(mod)
    @enabled << mod if @listing.include?(mod.intern)
  end
end


class Generator
  def initialize
    @separator = String.new
    @words = Array.new
    @tagger = EngTagger.new
  end

  attr_writer :template
  attr_writer :separator

  def modifiers(m)
    @modifiers = m
  end

  def source(source)
    text = @tagger.add_tags(source.words.join(' '))
    dom = Nokogiri.HTML(text)

    @source_dom = dom
  end

  def suggest
    words = Array.new
    @modifiers.enabled.each { |m|
      type = @modifiers.map m
      types = @source_dom.search(type.downcase)
      words << types[rand(types.size - 1)].text if types.length > 0
    }
    words.join(@separator)
  end
end


class Source
  def initialize
    @sources = Array.new
    @default = Array.new
    @text = Array.new
  end

  attr_accessor :sources
  attr_accessor :default
  attr_reader :text

  def add(source)
    @sources << source unless @sources.include?(source)
  end

  def words
    sources_to_text if @text.length == 0
    @text
  end
end


class SourceWords < Source
  def sources_to_text
    @sources = @default if @sources.length == 0
    @sources.each { |s| @text << s.downcase }
    @text
  end
end


class SourceSites < Source
  PATTERNS_TO_REMOVE = ['[0-9]', '\/', 'a']

  def initialize
    super
    @default << 'http://en.wikipedia.org/wiki/Special:Random'
  end

  private

  def sources_to_text
    @sources = @default if @sources.length == 0
    text = String.new

    for s in @sources
      source = open(s, :allow_redirections => :safe) { |f| f.read }
      dom = Nokogiri.HTML(source)
      dom.css('head,script,style,code').map { |l| l.unlink }
      text += dom.text
    end

    @text = clean_text(text)
  end

  def clean_text(text)
    text.gsub!(/[^a-zA-Z\s]+/, ' ')
    text = text.split(' ')
    PATTERNS_TO_REMOVE.each do |pattern|
      text.reject! { |word| word.match(pattern) }
    end
    text.map! { |word| word.downcase }
    text.uniq
  end
end


class Application
  include Commander::Methods

  def initialize
    @formatter = Formatter.new
    @modifiers = Modifiers.new
    @generator = Generator.new
  end

  def run
    program :name, 'RENAM'
    program :version, '1.0.0'
    program :description, 'Utility to return a randomly generated list of possible "release names" using different sources to create the dictionary of words used.'
    program :help, 'Authors', 'Rob Frawley 2nd <rmf@src.run>, Dan Corrigan <dfc@scribenet.com>'
    program :help, 'License', 'MIT License (https://rmf.mit-license.org)'

    global_option('-f', '--formater STRING', String, 'Set the output format the generated values will be returned in.')
    global_option('-F', '--list-formatters', 'Show available output formatters.') {
      @formatter.listing.each { |f| puts f }
      exit
    }
    global_option('-m', '--modifiers ARRAY', Array, 'Pass a variable number of modifiers to apply constrains/rules for the generator.')
    global_option('-M', '--list-modifiers', 'Show available modifiers.') {
      @modifiers.listing.each { |m| puts m }
      exit
    }
    global_option('-s', '--separator STRING', String, 'The character placed between modifiers in the resulting output.')
    global_option('-n', '--iterations INTEGER', Integer, 'The number of results returned for each command invokation.')
    global_option('-V',  '--verbose', 'Enable additional debug output during command execution.')

		command :'use-links' do |c|
      command_set_syntax c
      command_set_examples c
      command_set_info c

		  c.action do |args, options|
        @source = SourceSites.new

        command_set_default_options options
        command_set_options options
        command_set_arguments args

        @generator.source @source
        @generator.modifiers @modifiers

        results = Array.new
        options.iterations.times do |_x|
          results << @generator.suggest
        end

        @formatter.write @source, @modifiers, results
      end
    end

    command :'use-words' do |c|
      command_set_syntax c
      command_set_examples c
      command_set_info c

      c.action do |args, options|
        @source = SourceWords.new

        command_set_default_options options
        command_set_options options
        command_set_arguments args

        @generator.source @source
        @generator.modifiers @modifiers

        results = Array.new
        options.iterations.times do |_x|
          results << @generator.suggest
        end

        @formatter.write @source, @modifiers, results
      end
    end

    default_command :'use-links'

    run!

  end

  private

  def command_symbol(c)
    c.name.intern
  end

  def command_set_options(o)
    unless @formatter.listing.include?(o.formater.intern)
      say_error "Invalid option provided as output formatter: '#{o.formatter}'"
      exit
    end

    @formatter.enabled = o.formater.intern

    @modifiers.enabled = @modifiers.default if o.modifiers.length == 0
    o.modifiers.each do |m|
      unless @modifiers.listing.include?(m.intern)
        say_error "Invalid option provided as modifier: '#{m}'"
        exit
      end

      @modifiers.add(m.intern)
    end

    @generator.separator = o.separator
  end

  def command_set_default_options(o)
    o.default \
      :verbose => false,
      :iterations => 1,
      :separator => '_',
      :formater => 'text',
      :modifiers => %w(adjective noun)
  end

  def command_set_arguments(args)
    args.each { |a| @source.add(a) }
    @source.sources = @source.default if @source.sources.length == 0
  end

  def command_set_syntax(c)
    command = command_symbol(c)

    if command == :'use-links'
      arguments = 'links'
    elsif command == :'use-words'
      arguments = 'words'
    else
      arguments = 'args'
    end

    c.syntax = "renam #{c.name} [options] -- [<#{arguments}>]..."
  end

  def command_set_examples(c)
    command = command_symbol(c)
    command_examples = Hash.new
    command_arguments = Hash.new
    command_arguments[:'use-links'] = Array.new
    command_arguments[:'use-words'] = Array.new

    command_examples['List of 2 results with proper noun modifier as simple lines of text using long options:'] = "renam #{c.name} --iterations=2 --out-format=text --mods=proper_nouns arguments"
    command_arguments[:'use-links'] << "'https://en.wikipedia.org/wiki/Light-emitting_diode'"
    command_arguments[:'use-words'] << 'word_1 word_2 [...] word_n-1 word_n-0'

    command_examples['List of 20 results output as YAML using short options:'] = "renam #{c.name} -i20 -oyaml arguments"
    command_arguments[:'use-links'] << "'https://en.wikipedia.org/wiki/Semiconductor'"
    command_arguments[:'use-words'] << 'keys insert default [...] send mark ernie'

    command_examples['Single result using provided arguments as JSON using short options:'] = "renam #{c.name} -ojson arguments"
    command_arguments[:'use-links'] << "'https://en.wikipedia.org/wiki/Light-emitting_diode' [...] 'https://en.wikipedia.org/wiki/Semiconductor'"
    command_arguments[:'use-words'] << 'steve associative microphone [...] angry dog penultimate'

    i = 0
    command_examples.each do |description, example|
      c.example description, example.gsub(/arguments/, command_arguments[command][i])
      i += 1
    end
  end

  def command_set_info(c)
    command = command_symbol(c)

    command_summary = Hash.new
    command_description = Hash.new

    command_summary[:'use-links'] = 'Use passed links to source dictionary (default)'
    command_description[:'use-links'] = 'Fetch passed url HTML contents and utilize the returned set of words as the Renam dictionary for the generated output.'

    command_summary[:'use-words'] = 'Use CLI provided list for dictionary'
    command_description[:'use-words'] = 'Utalize the provided set of words on the command line as the Renam dictinary for the generated output.'

    command_description[command] += "\n\nNOTE: To view the complete list of available global CLI options, call --help without specifying either 'use-links' or 'use-words' as command name."

    c.summary = command_summary[command]
    c.description = command_description[command]
  end
end

Application.new.run if $0 == __FILE__
