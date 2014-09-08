# encoding: utf-8
require 'rbtagger'
require 'open-uri'
require 'nokogiri'

class ReleaseNamer
  def initialize(source, proper = nil)
    @proper = proper
    page = open(source) { |f| f.read }
    dom = Nokogiri.HTML(page)
    dom.css('head,script,style,code').map { |l| l.unlink }
    @text = dom.text
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

def repeater
  arg = ARGV.find { |x| x.match(/suggestions/) }
  return arg if arg.nil?
  arg.split(/=/).last.to_i
end

def proper_name
  arg = ARGV.find { |x| x.match(/proper/) }
  return arg if arg.nil?
  !!arg.split(/=/).last
end

site = ARGV.last
do_it = repeater || 1
proper = proper_name || false

namer = ReleaseNamer.new(site, proper)

do_it.times do |_x|
  puts namer.suggestion
end
