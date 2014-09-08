# Rando Namer

A quick script for auto-generating a release name in the [adjective]_[noun] format given a website as source input.

The NLP part-of-speech tagger isn't perfect, but what is?

## Setup

```
gem install rbtagger
gem install nokogiri
```

## Simple

```
ruby namer.rb http://en.wikipedia.org/wiki/Theodore_Roosevelt
=> significant_channing
```

## Better

```
ruby namer.rb --suggestions=5 --proper=1 http://en.wikipedia.org/wiki/Theodore_Roosevelt
=> post_indian
retrieved_trail
critical_toucey
domestic_indian
milkandwater_airdrop
```
