# Setting up an SSO client

## Assumptions

* You have a rack app (e.g. Rails)
* You are not going to have a database table with users in your OAuth Clients. That information is only available in the [Rails OAuth server](https://github.com/halo/sso/blob/master/lib/sso/server/README.md).
* To avoid implementing your own solutions, you should use `warden.user` to persist your user in the session in the OAuth rails clients. It is no problem to use warden scopes here in the client.

## How it works

#### Trusted OAuth clients

* A trusted OAuth client, let's call it `Alpha`, uses the `Authorization Code Grant` to obtain an OAuth `access_token` with the OAuth permission scope `insider`.
* The browser of the end user actually "visits" `Bouncer` for the login. That's where the user is persisted into the session. And that's where a passport is created for the user. So basically, through the OAuth server cookie, the SSO session is tied together. As long as it is there, you are logged in (in that browser e.g.).

#### Unstrusted OAuth clients

* A public OAuth Client, such as an `iPhone`, uses the `Resource Owner Password Credentials Grant` to exchange the `username` and `password` of the end user for an OAuth `access_token` with the OAuth permission scope `outsider`.
* You exchange the `access_token` for a passport token. That is effectively your API token used to communicate with the OAuth Rails clients.
* The OAuth Rails clients verify that token with the OAuth server at every request.
* In effect, this turns your iPhone app into a Browser, technically not a trusted OAuth Client.

#### Also good to know

* If the passport verification request times out (like 100ms), the authentication/authorization of the previous request is assumed to still be valid.

## Setup (trusted client)

#### Add the gem to your Gemfile

```ruby
# Gemfile
gem 'sso', require: 'sso/client'
```

#### Make sure you activated the Warden middleware provided by the `warden` gem

See [the Warden wiki](https://github.com/hassox/warden/wiki/Setup).
However, one thing is special here, you must not store the entire object, but only a reference to the passport.
If you store the entire object, that would be a major security risk and allow for cookie replay attacks.

```
class Warden::SessionSerializer
  def serialize(passport)
    Redis.set passport.id, passport.to_json
    passport.id
  end

  def deserialize(passport_id)
    json = Redis.get passport_id
    SSO::Client::Passport.new JSON.parse(json)
  end
end
```

#### Set the URL to the SSO Server

See [also this piece of code](https://github.com/halo/sso/blob/master/lib/sso/client/omniauth/strategies/sso.rb#L7-L17).

```bash
OMNIAUTH_SSO_ENDPOINT="http://server.example.com"
```

#### Setup your login logic

Rails Example:

```ruby
class SessionsController < ApplicationController
  delegate :logout, to: :warden

  def new
    redirect_to '/auth/sso'
  end

  def create
    warden.set_user auth_hash.info.to_hash
    redirect_to root_path
  end

  def destroy
    warden.logout
  end

  private

  def auth_hash
    request.env['omniauth.auth]
  end

  def warden
    request.env['warden']
  end

end
````

#### Activate the middleware

This is done by making use of [Warden callbacks](https://github.com/hassox/warden/wiki/Callbacks). See [this piece of code](https://github.com/halo/sso/blob/master/lib/sso/client/warden/hooks/after_fetch.rb#L18-L22).

```ruby
# e.g. config/initializers/warden.rb
# The options are passed on to `::Warden::Manager.after_fetch`
SSO::Client::Warden::Hooks::AfterFetch.activate scope: :vip
``
#### Profit

