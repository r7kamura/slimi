# Slimi

[![test](https://github.com/r7kamura/slimi/actions/workflows/test.yml/badge.svg)](https://github.com/r7kamura/slimi/actions/workflows/test.yml)
[![](https://badge.fury.io/rb/slimi.svg)](https://rubygems.org/gems/slimi)

Yet another implementation for [Slim](https://github.com/slim-template/slim) template language.

Slimi provides almost the same functionality as Slim, with a few additional useful features,
such as generating AST with detailed location information about embedded Ruby codes.
Originally, Slimi was developed for [Slimcop](https://github.com/r7kamura/slimcop), a RuboCop runner for Slim template.
It uses Slimi to apply `--auto-correct` to embedded Ruby codes in Slim template.

## Usage

Just replace `gem 'slim'` with `gem 'slimi` in your application's Gemfile.
