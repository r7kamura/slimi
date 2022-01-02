# Slimi

[![test](https://github.com/r7kamura/slimi/actions/workflows/test.yml/badge.svg)](https://github.com/r7kamura/slimi/actions/workflows/test.yml)
[![](https://badge.fury.io/rb/slimi.svg)](https://rubygems.org/gems/slimi)

Yet another implementation for [Slim](https://github.com/slim-template/slim) template language.

## Introduction

Slimi provides almost the same functionality as Slim, with a few additional useful features,
such as generating AST with detailed location information about embedded Ruby codes.

Originally, Slimi was developed for [Slimcop](https://github.com/r7kamura/slimcop), a RuboCop runner for Slim template.
It uses Slimi to apply `rubocop --auto-correct` to embedded Ruby codes in Slim template.

## Usage

Just replace `gem 'slim'` with `gem 'slimi'` in your application's Gemfile.

```ruby
gem 'slimi'
```

## Compatibility

- Line indicators
    - [x] Vebatim text
    - [x] Inline HTML
    - [x] Control
    - [x] Output
    - [x] HTML comment
    - [x] Code comment
    - [x] IE conditional comment
- Tags
    - [x] Doctype declaration
    - [x] Closed tags
    - [x] Trailing and leading white space
    - [x] Inline tags
    - [x] Text content
    - [x] Dynamic content
    - [x] Tag shortcuts
    - [ ] Dynamic tags
- Attributes
    - [x] Attributes wrapper
    - [x] Quoted attributes
    - [x] Ruby attributes
    - [x] Boolean attributes
    - [x] Attribute merging
    - [x] Attribute shortcuts
    - [ ] Splat attributes
- Plugins
    - [ ] Include partials
    - [ ] Translator/I18n
    - [ ] Logic-less mode
    - [ ] Smart text mode
- Etc.
    - [ ] CLI tools
- Slimi-only features
    - [x] Embedded Ruby code location
    - [x] annotate_rendered_view_with_filenames
