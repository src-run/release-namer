# encoding: utf-8
require 'rbtagger'
require 'open-uri'
require 'nokogiri'

class ReleaseNamer

  def initialize(sites, proper = nil)
    @proper = proper
    @text   = String.new
    for site in sites
      source = open(site) { |f| f.read }
      dom = Nokogiri.HTML(source)
      dom.css('head,script,style,code').map { |l| l.unlink }
      @text += dom.text
    end
  end

  def suggestion
    adj = pick_word(adjectives)
    noun = pick_word(nouns)
    "#{adj}_#{noun}"
  end

  private

  def cleanup_word(w)
    w.downcase!
    w.gsub!(/[\.,:;!\?=\\`\{\}\[\]\+\-\(\)" ]/, '')
  end

  def get_simple_list(tag_method)
    arr = tagger.send(tag_method, @text).map { |x, l| x }.uniq
    remove_bs(arr)
    arr
  end

  def get_subtler_list(tag_method, screeners = [])
    arr = tagger.send(tag_method, @text)
    arr.reject! { |x,t| !screeners.include?(t) }
    arr.map! { |x, l| x }.uniq
    remove_bs(arr)
    arr
  end

  BS = ['[0-9]', '\/']

  def bs_patterns
    BS.join('|')
  end

  def remove_bs(arr)
    arr.reject! { |x| x.match(bs_patterns) }
  end

  def tagger
    @tagger ||= Brill::Tagger.new
  end

  def pick_word(arr)
    pick = random_pick(arr)
    cleanup_word(pick)
    pick
  end

  def random_pick(arr)
    arr[rand(arr.size - 1)]
  end

  def adjectives
    @adjectives ||= get_simple_list(:adjectives)
  end

  def get_noun_list
    @proper ? get_subtler_list(:nouns, %w(NNP NNPS)) : get_simple_list(:nouns)
  end

  def nouns
    @nouns ||= get_noun_list
  end

end

class CLIArgs

  def sites

    argument_length = ARGV.length
    argument_offset = 0

    if @proper_defined == true
      argument_offset += 1
    end

    if @repeater_defined == true
      argument_offset += 1
    end

    sites = Array.new

    while ARGV[argument_offset]
      sites << ARGV[argument_offset]
      argument_offset += 1
    end

    return false if sites.length == 0
    return sites

  end

  def proper_name

    arg = ARGV.find { |x| x.match(/proper/) }
    
    if arg.nil?
      @proper_defined = false
      return arg
    else
      @proper_defined = true
      return !!arg.split(/=/).last
    end
  
  end

  def repeater
  
    arg = ARGV.find { |x| x.match(/suggestions/) }
  
    if arg.nil?
      @repeater_defined = false
      return arg
    else
      @repeater_defined = true
      return arg.split(/=/).last.to_i
    end
  
  end

end

def main

  cliargs = CLIArgs.new

  do_it  = cliargs.repeater    || 1
  proper = cliargs.proper_name || false
  sites  = cliargs.sites       || Array.new.push('http://en.wikipedia.org/wiki/Special:Random')

  namer = ReleaseNamer.new(sites, proper)

  do_it.times do |_x|
    puts namer.suggestion
  end

end

main

## EOF