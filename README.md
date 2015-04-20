[![Gem Version](https://img.shields.io/gem/v/sso.svg)](https://rubygems.org/gems/sso)
[![Build Status](https://travis-ci.org/halo/sso.svg?branch=master)](https://travis-ci.org/halo/sso)
[![License](http://img.shields.io/badge/license-MIT-blue.svg)](http://github.com/halo/sso/blob/master/LICENSE.md)
[![Join the chat at https://gitter.im/halo/sso](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/halo/sso)

# Single-Sign-On using Doorkeeper and Warden

**Current state of development:** Alpha at best!

This whole concept is already used in production by some, but I'm still not finished extracting all the code into a reusable gem to kickstart other developers who seek to implement it.

## Philosophy

* There is no shared data store involved
* It works even for OAuth clients (consumers) on different top-level domains
* It works on native apps
* Support for single-sign-out (per device)
* OAuth Access Tokens are short lived, just like the RFC suggests (refresh Tokens are not used at all).

## Requirements

* Client and server: **Ruby 2.1.0** (I like keywords arguments)
* Server: **PostgreSQL** (I like the `uuid`, `inet` and `hstore` column types)

## Setup

I refer to the separate README's for the [server](https://github.com/halo/sso/blob/master/lib/sso/server/README.md) and the [clients](https://github.com/halo/sso/blob/master/lib/sso/client/README.md).

## Terminology

It helps a lot using unambiguous words for different things. So I'll keep to the following convention thoughout *all* documentation.

* Our **end user** is called `Emily`, she has the **user ID** `42`.
* Her **browser** is called `Firefox`.
* Our **OAuth provider** we call `Bouncer` and it runs on the domain `bouncer.dev`.
  Just like at a nightclub, he knows *everything* about the end users.
* We will refer to `Alpha` and `Beta` as our **OAuth client web** applications running on the domains `alpha.dev` and `beta.dev`. These are *trusted* OAuth clients we have full control over.
* `iPhone` and `Android` are our **mobile OAuth client** native applications. Even though we also have full control over their code base, they considered are *untrusted* OAuth clients, because othing on these devices can be kept secret from `Emily`.

## How it works

I realize that you might want some sort of high-level overview first.
Unfortunately, I never succeeded in visualizing the entire architecture and its timeline in a *simple* way.
Also, there are many different cross-roads where either one or another thing may happen.

So bare with me as I will go through **one big use case** which includes all different parts of the system at one point or another.

### Logging in for the first time

Let's assume `Emily` is not logged in. She requests a protected resource on `Alpha`.

![](doc/emily_knocks_onto_alphas_door.png?raw=true)

`Alpha` checks `Emilys` cookie for `alpha.dev` by looking at `session[:passport_id]` and notices that she is not logged in.

At this point, `Alpha` initiates the standard OAuth 2.0 *Authorization Grant* flow by redirecting `Emily` to `Bouncer`.

> Show me the [code](https://github.com/halo/sso/blob/master/lib/sso/client/omniauth/strategies/sso.rb) and [what it's based on](https://github.com/intridea/omniauth).

![](doc/alpha_sends_emily_to_login.png?raw=true)

Now it's `Bouncers` turn to check for an existing session in the cookie of `bouncer.dev` and notices that `session[:passport_id]` is `nil`.

It's up to you to come up with an authentication mechanism on `Bouncer`.
You could e.g. use [Devise](https://github.com/plataformatec/devise), but usually it will look something like the following.

![](doc/bouncer_sends_to_login_form.png?raw=true)

At this point, `Emily` is presented with a login form and uses her credentials to authenticate herself.

![](doc/emily_presents_bouncer_credentials.png?raw=true)

Upon successful authentication, `Bouncer` creates a new record in its database in the following table.
Don't worry, by and by you will come to understand what the columns mean.

```ruby
# This table leverages Postgres-specific column types (uuid, inet, hstore).
# But there is no reason why this should not work with any other database.

enable_extension 'uuid-ossp'
enable_extension 'hstore'

create_table :passports, id: :uuid do |t|
  # Relationships with Doorkeeper-internal tables
  t.integer :oauth_access_grant_id     # OAuth Grant Token
  t.integer :oauth_access_token_id     # OAuth Access Token
  t.boolean :insider                   # Denormalized: Is the client app trusted?

  # Passport information
  t.integer :owner_id, null: false               # User ID
  t.string :secret, null: false, unique: true    # Random secret string

  # Passport activity
  t.datetime :activity_at, null: false   # Timestamp of most recent usage
  t.inet :ip, null: false                # Most recent IP which used this Passport
  t.string :agent                        # Post recent User Agent which used this Passport
  t.string :location                     # Human-readable city of the IP (geolocation)
  t.string :device                       # Mobile client hardware UUID (if applicable)
  t.hstore :stamps                       # Keeping track of *all* IPs which use(d) this Passport

  # Revocation
  t.datetime :revoked_at                 # If set, consider this record to be deleted
  t.string :revoke_reason                # Slug describing why deleted (logout, timeout, etc)
  t.timestamps null: false               # Internal Rails created_at and updated_at columns
end

# Doorkeeper is not guaranteed to create a new access token upon each login, it may just return an existing one
# That's why we need to check for `revoked_at`, only valid passports bear the constraint
add_index :passports, [:owner_id, :oauth_access_token_id], where: 'revoked_at IS NULL AND oauth_access_token_id IS NOT NULL', unique: true, name: :one_access_token_per_owner

add_index :passports, :oauth_access_grant_id
add_index :passports, :oauth_access_token_id
add_index :passports, :insider
add_index :passports, :owner_id
add_index :passports, :secret
add_index :passports, :activity_at
add_index :passports, :ip
add_index :passports, :location
add_index :passports, :device
add_index :passports, :revoked_at
add_index :passports, :revoke_reason
```

In the `oauth_applicationns` table, `Alpha` is defined to only allow the `insider` scope.
This is how Doorkeeper knows which consumers are trusted and which are not.

| id  | name    | scopes    | ... |
|:----|:--------|:----------|:----|
| `1` | `Alpha` | `insider` | ... |

So in this case, the following records will be created (long random UUIDs are simplified for readability).

First, Doorkeeper creates the OAuth **grant token** in its internal `oauth_access_grants` table.

| id    | resource_owner_id | application_id | token    | scopes  |
|:------|------------------:|:---------------|:---------|:--------|
| `111` |              `42` |            `1` | `1g1g1g` | insider |

Then the `sso` gem creates a Passport in its `passports` table which is related to that grant via the `oauth_access_grant_id` `111`.

`Bouncer` also sets the `insider` flag for this Passport, because `Bouncer` knows that `Doorkeeper` would not have handed out this `insider` Grant Token to an `outsider` OAuth consumer (such as the `iPhone` or `Android`).

| id       | owner_id | group_id | secret  | oauth_access_grant_id | oauth_access_token_id | insider |
|:---------|---------:|:---------|:--------|----------------------:|----------------------:|:--------|
| `aiaiai` |     `42` | `agagag` | `s3same`|                 `111` |                       | `true`  |

We also store the IP (and geolocation derived from the IP) when `Bouncer` creates the Passport.
The IP is taken directly from `request.ip` as it is `Emilys` `Firefox` which *directly* connects to `Bouncer`.

| id       | ... | ip              | agent         | location |
|:---------|-----|:----------------|:--------------|:---------|
| `aiaiai` | ... | `198.51.100.11` | `Firefox 1.0` | `Rome`   |

Additionally, it is useful to keep track of **all** IPs which used this Passport by storing them in the `hstore` field called `stamps`. Much like you would get a stamp in your Passport when you land at an international airport.

| id       | ... | stamps                                      |
|:---------|-----|:--------------------------------------------|
| `aiaiai` | ... | `{ "198.51.100.11" => "2015-12-24 20:00" }` |

While the `ip` column only contains the most recent IP and the `activity_at` column only contains the most recent activity, the `stamps` column contains both the latest IP and all previous IPs and their most recent activity timestamp.

Also, the `sso` gem persists the `passport_id` in the `bouncer.dev` cookie.

```ruby
session[:passport_id] = 'aiaiai'
```

From here, the usual OAuth dance between `Alpha` and `Bouncer` continues as Doorkeeper directs.
At the end of it, `Alpha` holds an OAuth access token (which is unknown to `Emily`).

Note that `Alpha`, being a *trusted* OAuth consumer, requests the OAuth scope `insider`.
This will later be relevant when *untrusted* OAuth consumers come into play, for which the scope `outsider` is reserved.

![](doc/doorkeeper_hands_out_alpha_grant.png?raw=true)

So, at this point, Doorkeeper creates an **access token** in its internal `oauth_access_tokens` table.

| id    | resource_owner_id | application_id | token    |
|:------|------------------:|:---------------|:---------|
| `222` |              `42` |            `1` | `2t2t2t` |

And the `sso` gem augments the existing passport with the `access_token_id` so that the passport record looks like the following. The `oauth_access_grant_id` is used to find the corresponding Passport.

| id       | ... | oauth_access_grant_id | oauth_access_token_id | insider |
|:---------|-----|----------------------:|----------------------:|:--------|
| `aiaiai` | ... |                 `111` |                 `222` | `true`  |

`Bouncer` also seizes the moment to update the IP meta information which `Alpha` was so kind to provide in `params[:ip]` and `params[:agent]` on behalf of `Firefox`.
`Bouncer` trusts the `params` to truthgully reflect `Firefoxes` IP, because the `insider` flag is `true`.

So, Doorkeeper hands over the new Access Token to Alpha.

![](doc/doorkeeper_hands_out_alpha_access_token.png?raw=true)

Technically, this is where the OAuth flow ends. There is nothing more in the RFC after this point.

`Alpha` now possesses an Access Token.
Per convention of the [OmniAuth](https://github.com/intridea/omniauth) gem, this Access Token is now used to ask `Bouncer`
for information about `Emily`.

> Show me the [code](https://github.com/halo/sso/blob/master/lib/sso/client/omniauth/strategies/sso.rb) `Alpha` uses for this.

![](doc/alpha_requests_passport_for_emily.png?raw=true)

`Bouncer` will not only return general information about `Emily`.
In our setup, the crucial information is the single-sign-on session information.
We call this a Passport and this is what it looks like deserialized by `Alpha`.

```ruby
# The ID and random secret of the corresponding Bouncer database record
passport.id     #=> "aiaiai"
passport.secret #=> "s3same"

# The user and a digest state of the user
passport.user   #=> <User @name="Emily" ...>
passport.state  #=> "asasas"

# An AES-encrypted blob which will be explained later (iPhone section)
passport.chip   #=> "¶§#&"
```

So what does `Alpha` do with this information? The information describes the authentication (and maybe even authorization) of the user and should obviously be persisted. Storing this information directly in a cookie would make you vulnerable to [cookie replay attacks](http://blog.astrumfutura.com/2012/01/s).

Instead, `Alpha` saves the passport ID in a `alpha.dev` cookie and stores the rest in some server side session database, e.g. Redis or ActiveRecord. Here is an example using Warden.

```ruby
# Example of Alpha storing session information on the server side, not in the Browser
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

The OAuth callback sends `Emily` back to the resource she requested in the beginning of this whole use case
(it's up to you to remember the path she originally requested before the OAuth dance began).

This time, `Emily` has a `alpha.dev` cookie with a valid Passport in it.

![](doc/emily_wants_resource_again.png?raw=true)

### Verifying authentication and authorization

But can `Alpha` really trust the Passport in the `alpha.dev` cookie?
`Alpha` has no knowledge about users at all.
So `Alpha` has to ask `Bouncer` at every request what the user looks like at the moment.

`sso` provides a Warden hook for just this functionality.
Whenever Warden  in `Alpha` deserializes `Emilys` Passport from the session store, it is automatically verified with `Bouncer`.

> Show me the [code](https://github.com/halo/sso/blob/master/lib/sso/client/warden/hooks/after_fetch.rb).

This is a public API endpoint, so as long as you are in possession of a Passport `id` and `secret` you can call it.

[Of course](http://swaggadocio.com/post/48223179207), we do not send the *actual* Passport `secret` over the Internet, but we sign the request with it.
Since Bouncer knows the `secret` it can verify the validity of the request sent by `Alpha`.

```ruby
# Pseudo code executed by Alpha to verify the Passport
params = {
  ip:    request.ip,
  agent: request.agent,
  state: passport.state,
}

url = "bouncer.dev/oauth/sso/v1/passports/#{passport.id}"
HTTParty.get url, params.sign(passport.secret)
```

So what is this `passport.state`?
It is a digest describing the [state of the user session](http://openid.net/specs/openid-connect-session-1_0.html#CreatingUpdatingSessions).
`Bouncer` will look up `Emily` in the database and calculate the digest of her current state with something like this.

```ruby
# Pseudo code of Bouncer calculating the user state digest
key   = "secret string only bouncer knows"
value = [emily.name, emily.email, emily...].join

state = HMAC(key, value)
```

If the state is the same as the one `Alpha` sent in, `Bouncer` now knows that `Alphas` information about all critical attributes of `Emily` is up-to-date.

If that is the case, Bouncer will just reply "alright".

![](doc/alpha_verifies_emilys_passport.png?raw=true)

There is one more thing happening in this process.
`Alpha` sent in meta information, such as IP and user agent in the `params`.
`Bouncer` can rely on these `params` because the Passport was created via the insider `Alpha`. If you think about it, nobody but `Alpha` actually knows the Passport.
So only `Alpha`, who established the Passport, can make this request to `Bouncer`.

`Alpha` is now free to trust the information it has about `Emily` and can hand out the resource to her.

![](doc/alpha_yields_resource_to_emily.png?raw=true)

###### Propagating user changes

Let's say, `Emily` changes her profile at this point. She changes her email address from `emily.legacy@example.com` to `emily@example.com`. Since `Bouncer` is the only one knowing about all users, that is where the change is persisted.

Let's say `Alpha` has a top navigation bar, which displays `emily.legacy@example.com`. At this point, only `Bouncer` knows about the new email address. So how does this information propagate to `Alpha`?

![](doc/alpha_passport_modified.png?raw=true)

As you can see, `Bouncer` simply told `Alpha` about it at a passport verification request. When `Bouncer` calculated `Emilys` user state, the digest was not the same any more (since `emily.email` is one of the user attributes included in the state calculation). `Bouncer` responds with the most recent Passport (including the new user and the new `state` digest, but without the `secret`). `Alpha` updates the local Passport accordingly.

By the way, only you as a developer can know which of `Emilys` attributes are included in the state digest calculation.
You might not care if her email address changes, but need to make sure her authorization rights are propagated as soon as possible. So you would have something like the following pseudo code in `Bouncer` (the `sso` gem allows you to configure the state calculation).

```ruby
# Fetch Emilys permissions in realtime from some database
emily.permissions = [:admin, :moderator, ...]

# Make the Passport state dependent on the set of permissions
HMAC(secret, "... #{emily.permissions} ...")
```

Just like before, `Bouncer` keeps track of the IP, geolocation, browser agent identifier and passport stamps for this Passport.
`Bouncer` updates this meta information by looking at the `params` which `Alpha` provided to `Bouncer`.
The `activity_at` timestamp is also updated.

###### Fallback if Bouncer goes down

Now you say:

> Wait a minute, so `Bouncer` is really just like a shared data store for the single-sign-on sessions, only that it is accessed via HTTP, and it's a single point of failure web app that has to respond really really fast?.

That's correct.

However, we optionally provide a fallback mechanism if `Bouncer` happens to not respond fast enough (within 10ms or so). Let's assume that `Emily` wants to see another resource. This time, however, `Bouncer` is under a DOS attack and does not respond to `Alphas` attempt to verify the information in the `alpha.dev` Passport..

![](doc/alpha_verification_times_out.png?raw=true)

If `Alpha` has a previously verified Passport about `Emily`, `Alpha` will use that information instead.

This way, Bouncer is not such a critical single point of failure which will cause every user to be logged out whenever `Bouncer` cannot respond within 10ms or there is network congestion.

###### Mitigating replay attacks

Conceptually, however, this opens up a vector for a replay attack. For the duration that `Bouncer` is down, all Passports are "frozen in" yet remain valid.

So `Firefox` could send in the same old Cookie and it would always be interpreted as the most recent Passport `Alpha` has in store. As soon as `Bouncer` comes up again (and successfully responds to a Passport verification request by `Alpha`), the most recent Passport is immediately propagated to `Alpha` again.

The attack window, then, lies between the most recent succeeded Passport verification request between `Alpha` and `Bouncer` and the next succeeding Passport verification request between `Alpha` and `Bouncer`.

In other words, if you notice that `Bouncer` is down, you better fix it fast or shut down critical services to avoid attacks.

Additionally, you should expire `insider` Passports persisted in `Alpha` (i.e. the Redis session store) if they have not been updated for, say a week or two. This way you can further minizime the attack window to be between 2 weeks in the past and `Bouncer` coming back online. (Unfortunately this does not work well with long-term `outsider` Passports of the native `iPhone` app. Simply because `Emily` didn't use the app for a few months, should not destroy her session between the `iPhone` and `Alpha`.)

If you go the other way and log out every user immediately if `Bouncer` does not respond, you may have a whole other problem. If an attacker can bring down `Bouncer`, all your end-users are logged out. But you can be rather sure that no unauthorized leak of resources occured.

There is a middle way, too. Every time the Passport verification succeeded, the Passport will respond positively to `passport.verified?`. If it is *not* verified, you might still want to show `Emilys` name in the navigation bar, but deny her to see sensitive account information or buying products. So she would not be logged *out* but would still have to wait until `Bouncer` is back up for critical use cases.

You'll have to decide for yourself whether to use the fallback mechanism or not. I'm just trying to lay out the advantages and disadvantages.

### Beta comes into play

Single-sign-on is just a concept which can look different from use case to use case. This becomes clear as soon as `Emily` (now already logged in on `Alpha` and `Bouncer`) surfs to `Beta`.

What would she see? Beta knows nothing about her.

1. `Beta` could simply always send `Emily` to `Bouncer` when she is not logged in.
   Since `Firefox` has a session with `Bouncer`, she would not even notice any redirect but would be immediately logged in on `Bouncer` as soon as this "automatic" OAuth dance with finishes.

  But should `Beta` really be unreachable without authentication?
  After all, we did not do something like this when `Emily` came to `Alpha` earlier today.

2. `Beta` could present a login button.
  Whenever `Emily` clicks on it, she would *suddenly* be logged in without entering a password.

  But is this maybe confusing to `Emily`?

A trade-off between these two solutions might be the following.

Whenever `Emily` surfs to `Beta`, `Beta` instructs her `Firefox` to make an AJAX call to something like `GET bouncer.dev/am_i_logged_in`.

If the answer is YES, i.e. there is a Passport ID in the `bouncer.ev` cookie, let JavaScript initiate the OAuth flow immediately.

 ```javascript
 window.location.href = '/auth/sso'
 ```

From `Emilys` point of view, she saw the page on `Beta` loading completely (saying "you are not logged in"). Then, suddenly the page disappears and comes back; this time she is logged in.

Additionally, whenver you cross-link from `Alpha` to `Beta` you might include a `?assume_logged_in=true` flag in the URL so that Bouncer can skip the AJAX request right away and perform the 302 redirect to `/auth/sso` without rendering anything first.

Either way, `Beta` will have to send `Firefox` to `Bouncer` by some means. So what happens exactly when `Firefox` meets `Bouncer` when there already is a session?

![](doc/beta_comes_into_play.png?raw=true)

At this point, `Bouncer` has access to the `bouncer.dev` cookie persisted in `Firefox` and can look up the ID of the Passport and find it in the database. When handing out the OAuth Grant token, `Bouncer` remembers the outgoing Grant by augmenting the Passport.

###### Doorkeeper oauth_access_grants Table

| id    | resource_owner_id | application_id | token    | scopes  |
|:------|------------------:|---------------:|:---------|:--------|
| `111` |              `42` |    (Alpha) `1` | `1g1g1g` | insider |
| `333` |              `42` |     (Beta) `2` | `2g2g2g` | insider |

###### Passports Table

| id       | ... | oauth_access_grant_id | oauth_access_token_id |
|:---------|-----|----------------------:|----------------------:|
| `aiaiai` | ... |                 `333` |                       |

As you can see, this process is analogous to when `Alpha` established a session, only that the Passport now does not need to be created from scratch, we re-use the existing one.

Note that the IP, geolocation, browser agent identifier, passport stamps, and `activity_at` are also updated, but I omitted the details here. This time, `Bouncer` uses `request.ip`, since `Firefox` is directly talking with `Bouncer`.

[So](https://twitter.com/avdi/status/473960505162219520), `Bouncer` hands out the OAuth Grant Token to `Firefox`, who gives it to `Beta`, who exchanges it for an Access Token and uses that Access Token to retrieve `Emilys` Passport from `Bouncer`. `Firefox` will then re-attempt accessing the `Beta` resource, whereupon `Bouncer` verifies the Passport with `Bouncer` and delivers the resource to `Firefox`.

![](doc/beta_oauth_dance.png?raw=true)

In this process, the Passport is also augmented with the newly created Access Token.

###### Doorkeeper oauth_access_tokens Table

| id    | resource_owner_id | application_id | token    | scopes  |
|:------|------------------:|:---------------|:---------|:--------|
| `222` |              `42` |    (Alpha) `1` | `2t2t2t` | insider |
| `444` |              `42` |     (Beta) `2` | `4t4t4t` | insider |

###### Passports Table

| id       | ... | oauth_access_grant_id | oauth_access_token_id |
|:---------|-----|----------------------:|----------------------:|
| `aiaiai` | ... |                 `333` |                 `444` |


Congratulations. `Emily` is now logged in on `Alpha` and `Beta`.
This works by keeping up the session between `Firefox` and `Bouncer`.
You could now proceed with logging in on `Gamma`, `Delta`, etc.

### Single-Sign-Out

This is simple. Just invalidate the Passport by setting the following flags.

###### Passports Table

| id       | ... | revoked_at         | revoke_reason |
|:---------|-----|:-------------------|:--------------|
| `aiaiai` | ... | `2015-12-24 21:00` | `logout`      |

Both `Alpha` and `Beta` know the passport ID so you could just create a logout link to `GET bouncer.dev/logout/aiaiai` and perform the revocation there.

Alternatively, `Alpha` could make a server-to-server request to `DELETE bouncer.dev/oauth/sso/v1/passports/aiaiai` and `Bouncer` executes the revocation then.
In this scenario, `Emily` would not end up seeing `Bouncer` telling her "you are logged out", but `Alpha` being able to tell her so.

Which one you use depends on whichever is more desirable in your use case.

As soon as `Emily` makes subsequent requests to `Alpha`, the Passport verification request from `Alpha` to `Bouncer` will inform `Alpha` to delete the local Passport entirely. The same is true for `Beta`.

This way we effectively logged out every session which was created using `Firefox` but leave those alive which were created using e.g. `Safari`.

> Just a gentle recapitulation: if `Bouncer` is down, the logout will not work. So you better ensure it is up and running to minimize the exploitation window.

### Native Clients (aka iPhone/Android)

In essence, a native client is like any other OAuth Client. Yet there are a few differences:

1. This client needs to authenticate to **other** **clients**, say, your API backend provided by `Alpha`.
2. There is **no way** you can hide **any** information on the device from the end user (this includes OAuth client credentials shared between `iPhone` and `Bouncer`).
3. `Android` needs to read the plain Passport to display `Emilys` name in the app. Remember that, so far, the Passport was located in an encrypted `alpha.dev` cookie unintelligible to `Firefox`.

Also, we really want to avoid HTML web views for login forms. The whole point of native apps is to not have to fallback to browser technology.

The `iPhone` is known to `Bouncer` as a `Doorkeeper::Application` in the internal Doorkeeper `oauth_applications` table. Only the scope `outsider` is allowed for native applications.

| id  | name     | scopes     | ... |
|:----|:---------|:-----------|:----|
| `1` | `Alpha`  | `insider`  | ... |
| `2` | `Beta`   | `insider`  | ... |
| `3` | `iPhone` | `outsider` | ... |

The corresponding OAuth client credentials are hardcoded in the `iPhone` app, and are considered public information (they [can easily](arstechnica.com/security/2010/09/twitter-a) be extracted by the end-user).

So let's do this.

###### Logging in for the first time

It start's with the `iPhone` sending `Emilys` username and password to `Bouncer`.
In return, the `iPhone` will get an OAuth Access Token (this is the OAuth *Resource Owner Password Credentials Grant*). That Token is exchanged for a Passport.

Basically, the iPhone acts as both, `Firefox` and `Alpha`.

![](doc/iphone_comes_into_play.png?raw=true)

During this process, Doorkeeper will create the Access Token in the internal `oauth_access_tokens` table (I omit showing any previous records here.
Anything that happened earlier only concerned the session between `Firefox` and `Bouncer`).

| id    | resource_owner_id | application_id | token    | scopes     |
|:------|------------------:|---------------:|:---------|:-----------|
| `555` |              `42` |   (iPhone) `3` | `5t5t5t` | `outsider` |

###### Passports Table

`Bouncer` creates a new Passport for this new single-sign-on session of this device.

| id       | ... | oauth_access_grant_id | oauth_access_token_id |
|:---------|-----|----------------------:|----------------------:|
| `bibibi` | ... |                       |                 `555` |


Earlier, `Bouncer` trusted the `params` provided by `Alpha` to update the Passport IP meta information.
This time, `Bouncer` recognized that this is an `outsider` request and retrieves that information directly by inspecting the incoming `request.ip` object.

The `agent` and `device UUID`, however, are still retrieved from the `params` (provided by the `iPhone`), since these are not reliable either way.

| id       | ... | ip              | agent    | location | device   |
|:---------|-----|:----------------|:---------|:---------|:---------|
| `bibibi` | ... | `198.51.100.22` | `iPhone` | `Venice` | `dedede` |

Now the `iPhone` has a Passport, `Emily` is logged in.

You probably want to persist the user information in some way. The Passport `secret` will typically not change and should be persisted in secure storage (e.g. KeyChain). The user object will be updated more frequently (i.e. whenever the user state changes).

###### Cross-client authentication and authorization

Now let the `iPhone` use its Passport to request a resource from `Alpha`.

What does the `iPhone` have to offer to `Alpha` so that `Alpha` would trust, or even be able to verify the signature of the request? Nothing. Since `Alpha` does not even know the Passport `secret`. And thus has to rely on `Bouncer` being able to tell `Alpha` whether the Passport is valid or not.

If `Alpha` would have some (even unreliable) idea of what the `secret` is, `Alpha` could at least verify the signature of the `iPhone` request, and `Alpha` could then use that `secret` to sign the Passport verification request to `Bouncer`.

Do you remember the Passport `chip` attribute?
It's a synchronously encrypted data store which `Bouncer` creates and the `iPhone` cannot decipher.
If we introduce a simple shared secret between `Bouncer` and `Alpha`, we could "transport" some information from `Bouncer` to `Alpha`.
This is how the Passport `secret` will come to `Alpha`.

When `Bouncer` handed out the Passport to the `iPhone`, it performed the following operation to put something in the Passport `chip`. This value is not stored in any database, it is simply "attached" to the Passport.

```ruby
# Pseudo code of Bouncer setting the chip of the Passport
shared_secret = "something only Bouncer, Alpha and Beta know (i.e. trusted clients)"
# Including the ID in the plaintext ensures the chip is only valid for this Passport
plaintext = [passport.id, passport.secret].join('|')
passport.chip = AES.encrypt(plaintext).with(shared_secret)
```

The `iPhone` simply passed on the `chip` to `Alpha`.
Upon receiving it, `Alpha` decrypts the chip and now knows the passport `secret`.
With that `secret`, `Alpha` is able to determine whether the `iPhone` properly signed the request with it.
Of course, `Alpha` **cannot trust** the `secret` (yet), but it is a practical approach for `Alpha` to be able to verify it with `Bouncer`).

So, the `iPhone` signs the request with the Passport `secret` and also sends along the Passport user `state` digest and the Passport `chip`.

![](doc/iphone_requests_alpha_resource.png?raw=true)

At this point, `Alpha` decrypts the `secret` from the `chip`, verifies the request and makes its own verification request to `Bouncer`.

Since this is the **first** request by `iPhone` to `Alpha`, `Alpha` has no information about `Emily` in some local datastore. So when `Alpha` makes its Passport verification request to `Bouncer`, `Alpha` will simply omit the `state` so as to guarantee to receive a user object.

But there is one more thing. `Bouncer` would like to update the Passport IP activity meta information, which `Alpha` has to provide by sending `iPhones` IP to `Bouncer` in the `params` . But `Bouncer` will not trust the `params` of this `outsider` Passport - after all the `iPhone` could perform the following request itself and forge `params[:ip]` to be something fake.

`Alpha` has to do some effort to have `Bouncer` trust in the `params[:ip]`. Signing the IP should suffice for this purpose.

```ruby
# Pseudo code of Alpha signing the IP proxied by Alpha from the iPhone to Bouncer
alpha_client_id     = "Alphas OAuth Client ID"
alpha_client_secret = "Alphas OAuth Client Secret"

params[:ip]         = "198.51.100.22"   # iPhone IP
params[:insider_id] = alpha_client_id   # So that Bouncer knows who Alpha is

params[:insider_signature] = HMAC.calculate(params[:ip]).with(alpha_client_secret)
```

`Bouncer` can lookup `Alphas` client secret in its Doorkeeper `oauth_applications` table and verify the signature to see if `params[:ip]` really is to be trusted.

![](doc/alpha_verifies_iphone_passport.png?raw=true)

Now `Alpha` can persist the Passport, including the user, in its local data store. From now on the `chip` sent by the `iPhone` can be ignored (but the iPhone needs to keep sending the `chip`  because the `iPhone` does not know wether `Alpha` or `Beta` needs it or not).

Any subsequent verification request from `Alpha` to `Bouncer` includes the `state` as usual. The response may not contain a user if the user `state` did not change meanwhile.

![](doc/alpha_verifies_iphone_passport_again.png?raw=true)

The response by `Bouncer` can even fail while `Alpha` will fallback to the previously verified Passport (along with all security implications previously explained).

![](doc/alpha_verifies_iphone_passport_fails.png?raw=true)

However, if it is the **first** time the `iPhone` talks to `Alpha`, the request from `Alpha` to `Bouncer` **must** succeed - in order to fetch a user. You need to be prepared for these kinds of errors in the `iPhone` app and retry or inform the user to try again later.

If the user object changed, `Alpha` informs the `iPhone` by delivering the new Passport `state` and `user` as a param

So, to summarize, the `iPhone` always sends in Passport `id`, `state` and `chip` and any **trusted** OAuth client (`Alpha`, `Beta`) can receive this information at any time and get the authentication/authorization information from `Bouncer`.

Are you dizzy? Me too.

# Development

How to run the specs:

```ruby
# RAILS_ENV is "test" by default.
# If you want "development", you have to `cd specs/dummy` first.
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rspec
```

Good to know:

* You can always `git grep POI` to see some points of interest. They will be properly documented as development progresses.
* You should tail `spec/dummy/log/test.log` because it's really helpful

### Contributing

* The [CHANGELOG](https://github.com/halo/sso/blob/master/CHANGELOG.md) follows [this](https://github.com/tech-angels/vandamme/#changelogs-convention) format.

# License

MIT 2015 halo, see [LICENSE](https://github.com/halo/sso/blob/master/LICENSE.md)
