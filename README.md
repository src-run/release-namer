# Rando Namer

A quick script for auto-generating a release name in the [adjective]_[noun] format given a website as source input.

The NLP part-of-speech tagger isn't perfect, but what is?

## Setup

```bash
gem install rbtagger
gem install nokogiri
```

## Simple Usage

With no arguments, one suggestion will be returned using the argument defaults. When no website is passed, it defaults to [Special:Random](http://en.wikipedia.org/wiki/Special:Random) which loads a random article from Wikipedia.

```bash
ruby namer.rb
```

Returns:
- available_metres

## Better Usage

You can optionally pass the number of suggections you want returned, enforce proper nouns, and a list of zero or more websites to crawl - used to determine the words available for the suggestions.

### Better Example 1

```bash
ruby namer.rb --suggestions=5 --proper=1
```

Returns:
- intext_creative
- spanish_theologia
- precise_deutsch
- mystic_Ávila
- stark_ariosophy

### Better Example 2

```bash
ruby namer.rb --suggestions=5 --proper=1 \
	http://en.wikipedia.org/wiki/Theodore_Roosevelt
```

Returns:
- post_indian
- retrieved_trail
- critical_toucey
- domestic_indian
- milkandwater_airdrop

### Better Example 3

```bash
ruby namer.rb --suggestions=5 --proper=1 \
	http://en.wikipedia.org/wiki/Theodore_Roosevelt \
	http://en.wikipedia.org/wiki/Franklin_D._Roosevelt
```

Returns:
- ill_november
- panamanian_allen
- stopwatch_fdr
- difficult_w
- monetary_roosevelt
