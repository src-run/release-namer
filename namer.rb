#!/usr/bin/env ruby

##
## Release Namer
##
## @license: MIT License
## @author : Dan Corrigan <github.com/dcorrigan>
##

require 'optparse'
require 'rbtagger'
require 'open-uri'
require 'open_uri_redirections'
require 'nokogiri'

class ReleaseNamer

  def initialize(sites, proper = nil)
    @proper = proper
    @text   = String.new
    for site in sites
      source = open(site, :allow_redirections => :safe) { |f| f.read }
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

def main

  opts = {}
  optparse = OptionParser.new do|o|
    o.banner = "Usage:\n"+
      "  release-namer [options] [--] [<url-resources>]...\n\n"+
      "Example:\n"+
      "  release-namer --count=20 -P \"https://en.wikipedia.org/wiki/Computer_science\" \"https://en.wikipedia.org/wiki/Art\"\n\n"+
      "Options:"

    opts[:count] = 1
    o.on('-c', '--count INT', 'Number of results to return.') do|count|
      opts[:count] = count.to_i
    end

    opts[:proper] = false
    o.on('-P', '--proper', 'Include a proper noun in results.') do
      opts[:proper] = true
    end

    o.on('-h', '--help', 'Display this help message.') do
      puts o
      exit 255
    end

    o.on('-v', '--version', 'Show script version string.') do
      puts "release-namer v0.1.0"
      exit 0
    end
  end

  optparse.parse!

  opts[:sites] = Array.new
  ARGV.each do|s|
    opts[:sites] << s
  end

  opts[:sites] << 'http://en.wikipedia.org/wiki/Special:Random' if opts[:sites].length == 0

  namer = ReleaseNamer.new(opts[:sites], opts[:proper])

  opts[:count].times do |_x|
    puts namer.suggestion
  end

end

main

## EOF
