[![Gem Version](https://img.shields.io/gem/v/sso.svg)](https://rubygems.org/gems/sso)
[![Build Status](https://travis-ci.org/halo/sso.svg?branch=master)](https://travis-ci.org/halo/sso)
[![License](http://img.shields.io/badge/license-MIT-blue.svg)](http://github.com/halo/sso/blob/master/LICENSE.md)
[![Join the chat at https://gitter.im/halo/sso](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/halo/sso)

## Leveraging Doorkeeper (OAuth) as single-sign-on server

### How it works

The purpose of this gem is to help you with [this complicated SSO flow](https://github.com/halo/sso/blob/master/doc/flow.pdf).

The code is already in use in production but needs to be extracted into this gem, which is about to happen.

* Our **end user** is called `Carol`.
* Our **OAuth provider** we call `Bouncer` and it runs on the domain `bouncer.dev`.
  Just like at a nightclub, he knows *everything* about the end users.
* We will refer to `Alpha` and `Beta` as our **OAuth client web** applications running on the domains `alpha.dev` and `beta.dev`. These are *trusted* OAuth clients.
* `iPhone` and `Android` are our **mobile OAuth client** native applications. These are *untrusted* OAuth clients.

# Setup

I refer to the separate README's for the [server](https://github.com/halo/sso/blob/master/lib/sso/server/README.md) and the [clients](https://github.com/halo/sso/blob/master/lib/sso/client/README.md).

# Development

Requirements:

* Ruby 2.1.0 (I think that's demanded for optional method keywords arguments or whatever they're called)
* PostgreSQL running in the background (There are uuid and inet column types for the Passport)

How to run the specs:

```ruby
# RAILS_ENV is "test" by default.
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rspec
```

Good to know:

* You can always `git grep POI` to see some points of interest. They will be properly documented as development progresses.
* You should tail `spec/dummy/log/test.log` because it's really helpful

### Contributing

* The [CHANGELOG](https://github.com/halo/sso/blob/master/CHANGELOG.md) follows [this](https://github.com/tech-angels/vandamme/#changelogs-convention) format.
