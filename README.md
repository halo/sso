[![Build Status](https://travis-ci.org/halo/sso.svg?branch=master)](https://travis-ci.org/halo/sso)
[![License](http://img.shields.io/badge/license-MIT-blue.svg)](http://github.com/halo/sso/blob/master/LICENSE.md)
[![Join the chat at https://gitter.im/halo/sso](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/halo/sso)

The purpose of this gem is to do [this](https://github.com/halo/oauth-sso/blob/master/flow.pdf).

The code is already in use in production but needs to be extracted into this gem, which is about to happen.

### General Assumptions

* You use doorkeeper as a Rails OAuth server.
* You want to provide single-sign-on for the end-users.
* All OAuth clients ("consumers") are developed by you. You have full control over them and can automatically trust them (i.e. you can set `skip_authorization { true }` in your doorkeeper.rb initializer). This makes sense, because why would you ask the end-user for permission to login to another subsystem of your SSO world? The whole idea with SSO is that your users don't need to notice switching between the OAuth clients.
* You are not going to have a database table with users in your OAuth Clients. That information is only available in the Rails OAuth server.
* The SSO session is to be browser-wide and app-wide. If you click on "login" you will be logged in on every client web app in that browser. If you click on "logout" you will be logged out of every client web app in that browser.
* To avoid implementing your own solutions, you should use `warden.user` to persist your user in the session in the OAuth rails clients. It is ok to use warden scopes here.
* You use warden to login at the SSO server, it is, however, **not** okay to use scopes here. That's an assumption which makes this gem dramatically more simple and I didn't find a downside yet (Warden scopes are not really an ideal authorization solution anyway).

### Architecture

* Our **end user** is called `Carol`.
* Our **OAuth provider** we call `Bouncer` and it runs on the domain `bouncer.dev`.
  Just like at a nightclub, he knows *everything* about the end users.
* We will refer to `Alpha` and `Beta` as our **OAuth client web** applications running on the domains `alpha.dev` and `beta.dev`. These are *trusted* OAuth clients.
* `iPhone` and `Android` are our **mobile OAuth client** native applications. These are *untrusted* OAuth clients.

### Flow for trusted OAuth clients

* A trusted OAuth client, let's call it `Alpha`, uses the `Authorization Code Grant` to obtain an OAuth `access_token` with the OAuth permission scope `insider`.
* The browser of the end user actually "visits" `Bouncer` for the login. That's where the user is persisted into the session. And that's where a passport is created for the user. So basically, through the OAuth server cookie, the SSO session is tied together. As long as it is there, you are logged in (in that browser e.g.).

#### Unstrusted OAuth clients

* A public OAuth Client, such as an `iPhone`, uses the `Resource Owner Password Credentials Grant` to exchange the `username` and `password` of the end user for an OAuth `access_token` with the OAuth permission scope `outsider`.
* You exchange the `access_token` for a passport token. That is effectively your API token used to communicate with the OAuth Rails clients.
* The OAuth Rails clients verify that token with the OAuth server at every request.
* In effect, this turns your iPhone app into a Browser, technically not an OAuth Client.

### Also good to know

* If the passport verification request times out (like 100ms), the authentication/authorization of the previous request is assumed to still be valid.

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
