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

Let's assume `Emily` is not logged in. She requests a protected resource on Alpha.

![](doc/emily_knocks_onto_alphas_door.png?raw=true)

Alpha checks Emily's cookie for `alpha.dev` by looking at `session[:passport_id]` and notices that the is not logged in.

At this point, `Alpha` initiates the standard OAuth 2.0 flow by redirecting Emily to `Bouncer`.
This mechanism is provided by [OmniAuth::Strategy](https://github.com/intridea/omniauth)
which the `sso` gem
[leverages](https://github.com/halo/sso/blob/master/lib/sso/client/omniauth/strategies/sso.rb).

![](doc/alpha_sends_emily_to_login.png?raw=true)

Now it's `Bouncers` turn to check for an existing session in the cookie of `bouncer.dev` and notices that `session[:passport_id]` is `nil`.

It's up to you to come up with an authentication mechanism on `Bouncer`.
You could e.g. use [Devise](https://github.com/plataformatec/devise), but usually it will look something like the following.

![](doc/bouncer_sends_to_login_form.png?raw=true)

At this point, `Emily` is presented with a login form and uses her credentials to authorize herself.

![](doc/emily_presents_bouncer_credentials.png?raw=true)

Upon successful authentication, `Bouncer` creates a new record in the database in the following table.
Don't worry, by and by you will come to understand what the columns mean.

```ruby
# This table leverages Postgres-specific column types (uuid, inet, hstore).
# But there is no reason why this should not work with any other database.

create_table :passports, id: :uuid do |t|
  # Relationships with Doorkeeper-internal tables
  t.integer :oauth_access_grant_id
  t.integer :oauth_access_token_id

  # Passport information
  t.integer :owner_id, null: false
  t.string :group_id, null: false
  t.string :secret, null: false, unique: true

  # Passport activity
  t.datetime :activity_at, null: false
  t.inet :ip, null: false
  t.string :agent
  t.string :location
  t.string :device
  t.hstore :stamps

  # Revocation
  t.datetime :revoked_at
  t.string :revoke_reason
  t.timestamps null: false
end
```

So in this case, the following records will be created. Long random UUIDs are simplified for readability.

First, Doorkeeper creates the OAuth **grant token** in its own table.

###### Doorkeeper oauth_access_grants Table

| id    | resource_owner_id | application_id | token    | scopes  |
|:------|------------------:|:---------------|:---------|:--------|
| `111` |              `42` |            `1` | `1g1g1g` | insider |

###### Passports Table

Then the `sso` gem creates a passport which is related to that grant via the `oauth_access_grant_id` `111`.

| id       | owner_id | group_id | secret  | oauth_access_grant_id | oauth_access_token_id |
|:---------|---------:|:---------|:--------|----------------------:|----------------------:|
| `aiaiai` |     `42` | `agagag` | `s3same`|                 `111` |                       |

We also store the IP (and geolocation derived from the IP) when `Bouncer` creates the Passport.
The IP is taken directly from the `request.remote_ip` object as it is `Emilys` `Firefox` which directly connects to `Bouncer`.

| id       | ... | ip              | agent         | location |
|:---------|-----|:----------------|:--------------|:---------|
| `aiaiai` | ... | `198.51.100.11` | `Firefox 1.0` | `Rome`   |


Additionally, it is useful to keep track of **all** IPs which used this Passport by storing them in the `hstore` field called `stamps`.
Just like in real life, you would get a stamp in your Passport when you land at an international airport. While the `ip` column only has the latest IP and the `activity_at` only has the latest activity, the `stamps` column contains both the latest IP and all previous IPs and their most recent activity timestamp.

This is useful to detect session highjacking (i.e. someone stole `Emilys` cookie and uses the very same passport as she does).

| id       | ... | stamps                                      |
|:---------|-----|:--------------------------------------------|
| `aiaiai` | ... | `{ "198.51.100.11" => "2015-12-24 20:00" }` |



Also, the `sso` gem persists the `passport_id` in the `bouncer.dev` cookie using

```ruby
session[:passport_id] = 'aiaiai'
```

From here, the usual OAuth dance between `Alpha` and `Bouncer` continues as Doorkeeper directs.
At the end of it, Alpha holds an OAuth access token which is unknown to `Emily`.

Note that `Alpha`, being a *trusted* OAuth consumer, requests the OAuth scope `insider`.
This will later be relevant when *untrusted* OAuth consumers come into play, for which the scope `outsider` is reserved.

![](doc/doorkeeper_hands_out_alpha_grant.png?raw=true)

In the `oauth_applicationns` table, `Alpha` is defined to only allow the `insider` scope. This is how Doorkeeper knows which consumers are trusted and which not.

###### Doorkeeper oauth_applications Table

| id  | name    | scopes    | ... |
|:----|:--------|:----------|:----|:
| `1` | `Alpha` | `insider` | ... |


So, at this point, Doorkeeper creates an **access token** in its own table.

###### Doorkeeper oauth_access_tokens Table

| id    | resource_owner_id | application_id | token    | scopes  |
|:------|------------------:|:---------------|:---------|:--------|
| `222` |              `42` |            `1` | `2t2t2t` | insider |

And the `sso` gem augments the existing passport with the `access_token_id` so that the passport record looks like the following. The `oauth_access_grant_id` is used to find the corresponding passport.

###### Passports Table

| id       | ... | oauth_access_grant_id | oauth_access_token_id |
|:---------|-----|----------------------:|----------------------:|
| `aiaiai` | ... |                 `111` |                 `222` |


So, doorkeeper hands over the new `access token` to Alpha.

![](doc/doorkeeper_hands_out_alpha_access_token.png?raw=true)

Technically, this is where the OAuth flow ends. There is nothing more in the RFC after this point.

Alpha now possesses an `access token`.
Per convention of the [OmniAuth](https://github.com/intridea/omniauth) gem, this `access token` is now used to ask `Bouncer`
for information about `Emily`.

The `Omniauth::Strategy` middleware [provided by sso](https://github.com/halo/sso/blob/master/lib/sso/client/omniauth/strategies/sso.rb)
helps you by providing an endpoint at `bouncer.dev/oauth/sso/v1/passports` which answers these requests.

![](doc/alpha_requests_passport_for_emily.png?raw=true)

Bouncer will not only return general information about `Emily`. In our setup, the crucial information is the single-sign-on session information. We call this a Passport and this is what it looks like once deserialized on the client side.

```ruby
# The ID and random secret of the corresponding Bouncer database record
passport.id     #=> "aiaiai"
passport.secret #=> "s3same"

# The user and a digest state of the user
passport.user   #=> <User @name="Emily" ...>
passport.state  #=> "asasas"

# An AES-encrypted blob which will be needed later
passport.chip   #=> "¶§#&"
```

So what does `Alpha` do with this information? The information describes the authentication (and maybe even authorization) of the user and should obviously be persisted.

So `Alpha` puts the passport ID in a `alpha.dev` cookie and stores the rest in some server side session database, e.g. Redis or ActiveRecord.
Storing this information directly in a cookie would make you vulnerable to [cookie replay attacks](http://blog.astrumfutura.com/2012/01/s).

It is strongly recommended that you implement this logic in a warden serializer.
Because the `sso` gem provides many useful helper classes which rely on the Passport residing inside Warden.

```ruby
# Example server side session store serialization
class Warden::SessionSerializer
  def serialize(passport)
    Redis.set passport.id, passport.to_json
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
So `Alpha` has to ask `Bouncer` at every request what the user (usually including her permissions) looks like at the moment.

`sso` provides a [Warden hook](https://github.com/halo/sso/blob/master/lib/sso/client/warden/hooks/after_fetch.rb) for just this functionality.
Whenever `Alpha` Warden deserializes `Emilys` Passport from the session store, it automatically verifies it with `Bouncer`.

This is a public API endpoint, so as long as you are in possession of a Passport `id` and `secret` you can call it. `Alpha` also sends in the current IP and other meta information about `Emily` as params.

[Of course](swaggadocio.com/post/48223179207), we don't send the actual Passport `secret` over the Internet, but we sign the request with it. Since Bouncer knows the `secret` it can verify the validity of the request.

```ruby
# Pseudo code executed by Alpha to verify the Passport
params = {
  ip:    request.remote_ip,
  agent: request.agent,
  state: passport.state,
  insider_id: "Alphas OAuth Client ID,
  insider_signature: HMAC(consumer_secret, ip),
}

HTTParty.get url, params.sign(passport.secret)
```

So what is this `passport.state`? It is a digest describing the [state of the user session](http://openid.net/specs/openid-connect-session-1_0.html#CreatingUpdatingSessions).
`Bouncer` will look up `Emily` in the database and calculate the digest of her current state with something like this.

```ruby
# Pseudo code showing the user state digest calculation
HMAC(secret, "#{emily.name} #{emily.email} #{emily...}")
```

If the state is the same as the one `Alpha` sent in, `Bouncer` now knows that `Alphas` information about all critical attributes of `Emily` is up-to-date.


If that is the case, Bouncer will just reply "alright".

![](doc/alpha_verifies_emilys_passport.png?raw=true)

> Experimental: Did you notice the `ip_signature` and `client_id` params? These are simply so that `Alpha` can proof to `Bouncer` that the IP param has not been tampered with. After all, `Firefox` could send in that request to `Bouncer` directly and specify any desirable IP. So `Bouncer` uses the `Alpha` OAuth consumer credentials to make sure `Alpha` is really an `insider`.

`Alpha` is now free to trust the information it has about `Emily` and can hand out the resource to her.

![](doc/alpha_yields_resource_to_emily.png?raw=true)

###### Propagating user changes

Let's say, `Emily` changes her profile at this point. She changes her email address from `emily.legacy@example.com` to `emily@example.com`. Since `Bouncer` is the only one knowing about all users, that is where the change is persisted.

Let's say `Alpha` has a top navigation bar, which displays `emily.legacy@example.com`. At this point, only `Bouncer` knows about the new email address. So how does this information propagate to `Alpha`?

![](doc/alpha_passport_modified.png?raw=true)

As you can see, `Bouncer` simply told `Alpha` about it at a passport verification request. When `Bouncer` calculated `Emilys` user state, the digest was not the same any more (since `emily.email` is one of the user attributes included in the state calculation). `Bouncer` responds with the most recent Passport (including the new state digest). `Alpha` updates the local Passport accordingly.

By the way, only you as a developer can know which of `Emilys` attributes are included in the state digest calculation.
You might not care if her email address changes, but need to make sure her authorization rights are propagated as soon as possible. So you would have something like the following pseudo code in `Bouncer` (the `sso` gem allows you to configure the state calculation).

```ruby
# Fetch Emilys permissions in realtime from some database
emily.permissions = [:admin, :moderator, ...]

# Make the Passport state dependent on the set of permissions
HMAC(secret, "... #{emily.permissions} ...")
```

One more thing. We would like to keep track of the IP, geolocation, browser agent identifier and passport stamps for this Passport, but `Bouncer` cannot simply look at the `request.ip`, because it is `Alpha` talking to Bouncer, not `Firefox`. So Bouncer will update this meta information by looking at the `params` which `Alpha` provided for `Bouncer`. The `activity_at` timestamp is also updated. I omit more details on these steps here. The `sso` gem does these things for you if you want.

Now you say:

> Wait a minute, so `Bouncer` is really just like a shared data store for the single-sign-on sessions, only that it is accessed via HTTP, and it's a single point of failure web app that has to respond really really fast?.

That's correct.

However, we optionally provide a fallback mechanism if `Bouncer` happens to not respond fast enough (within 10ms or so). Let's assume that `Emily` wants to see another resource. This time, however, `Bouncer` is under a DOS attack and does not respond to `Alphas` attempt to verify the information in the `alpha.dev` Passport..

![](doc/alpha_verification_times_out.png?raw=true)

If `Alpha` has previously trusted Passport information about `Emily`, `Alpha` will use that information instead.

This way, Bouncer is not such a critical single point of failure which will cause every user to be logged out whenever `Bouncer` cannot respond within 10ms or there is network congestion.

###### Mitigating replay attacks

Conceptually, however, this opens up a vector for a replay attack:

* If the Passport (i.e. user authentication **and** authorization) resides in the cookie, `Emily` can send an old cookie to `Alpha` over and over again until `Bouncer` randomly times out. The timeout will cause `Alpha` to deliver the resource to `Emily` even though her permissions have been revoked lately.

This is mitigated by solely storing a *reference* to the Passport in the `alpha.dev` cookie (as explained earlier).
No matter how old the cookie is, `Alpha` will only lookup the most recent version of the local Passport (e.g. stored in Redis).

In other words, for the duration that `Bouncer` is down, all Passports are "frozen in" yet remain valid.
As soon as `Bouncer` comes up again (and successfully responds to a Passport verification request by `Alpha`), the most recent Passport state is immediately propagated to `Alpha` again.

The attack window, then, lies between the most recent succeeded Passport verification request and the next succeeding Passport verification request.

In yet other words, if you notice that `Bouncer` is down, you better fix it fast or shut down critical services to avoid attacks.

This is still not ideal, of course. Because `Emily` could login on `Alpha` without performing any more requests for a year or two. After that, she DOSes `Bouncer` and authenticates with `Alpha` using the cookie which corresponds to a stone age old Passport.

This can be mitigated by timing out passports in the local storage of `Alpha`.
Unfortunately that does not work well with long-term sessions as on the native `iPhone` and `Android` apps.
Simply because `Emily` didn't use the app for a few months, should not destroy her `Alpha` or `Beta` session. However, you might be willing to take that risk if you trust `Bouncer` to be up and running *most of the times*.

If you go the other way and log out every user immediately if `Bouncer` does not respond, you may have a whole other problem. If an attacker can bring down `Bouncer`, all your end-users are logged out. But you can be rather sure that no unauthorized leak of resources occured.

There is a middle way for this, too. Every time the Passport could be verified, it will respond with `true` when you ask it `passport.verified?`. If it is not verified, you might still want to show `Emilys` name in the navigation bar, but deny her to see sensitive account information or buying products. So she would not be logged out but would have to wait until `Bouncer` is back up.

You'll have to decide for yourself whether to use the fallback mechanism or not. I'm just trying to lay out the advantages and disadvantages.

###### Beta comes into play

Single-sign-on is just a concept which can look different from use case to use case. This becomes clear as soon as `Emily` (now already logged in on `Alpha` and `Bouncer`) surfs to `Beta`.

What would she see? Beta knows nothing about her.

1. `Beta` could simply always send `Emily` to `Bouncer` when she is not logged in on `Beta`.
   Since `Emily` has a session with `Bouncer`, she would not even notice any redirect but would be immediately logged in on `Bouncer` as soon as this "automatic" OAuth dance with finishes.

  But should `Beta` really be unreachable without authentication?
  After all, we did not do something like this when `Emily` came to `Alpha` earlier today.

2. `Beta` could present a login button.
  Whenever `Emily` clicks on it, she would *suddenly* be logged in without entering a password.

  But is this maybe confusing to `Emily`?

A trade-off between these two solutions might be the following.

Whenever `Emily` surfs to `Beta`, `Beta` instructs her `Firefox` to make an AJAX call to something like `bouncer.dev/am_i_logged_in`.

If the answer is YES (i.e. there is a `Bouncer` cookie session), let JavaScript initiate the OAuth flow immediately.

 ```javascript
 window.location.href = '/auth/sso'
 ```

From `Emilys` point of view, she saw the page on `Beta` loading completely (in a not-logged-in state). Then, suddenly the page disappears and comes back; this time she is logged in.

Additionally, whenver you cross-link from `Alpha` to `Beta` you might include a `?assume_logged_in=true` flag in the URL so that Bouncer can skip the AJAX request right away and perform the 302 redirect to `/auth/sso` without rendering anything first.

Either way, `Beta` will have to send `Firefox` to `Bouncer` by some means. So what exactly happens when `Firefox` meets `Bouncer` when there already is a session?

![](doc/beta_comes_into_play.png?raw=true6)

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

Note that the IP, geolocation, browser agent identifier, passport stamps, and `activity_at` are also updated, but I omitted that here. Usually this does not change so fast, too. This time, `Bouncer` has direct access to this meta information in `request.ip`, since `Firefox` is directly talking with `Bouncer`.

So, `Bouncer` hands out the OAuth grant token to `Firefox`, who gives it to `Beta`, who exchanges it for an access token and uses that token to retrieve `Emilys` Passport from `Bouncer`. `Firefox` will then re-attempt accessing the `Beta` resource, whereupon `Bouncer` verifies the Passport with `Bouncer` and delivers the resource to `Firefox`.

![](doc/beta_oauth_dance.png?raw=true)

In this process, the passport is also augmented with the newly created access token.

###### Doorkeeper oauth_access_tokens Table

| id    | resource_owner_id | application_id | token    | scopes  |
|:------|------------------:|:---------------|:---------|:--------|
| `222` |              `42` |    (Alpha) `1` | `2t2t2t` | insider |
| `444` |              `42` |     (Beta) `2` | `4t4t4t` | insider |

###### Passports Table

| id       | ... | oauth_access_grant_id | oauth_access_token_id |
|:---------|-----|----------------------:|----------------------:|
| `aiaiai` | ... |                 `333` |                 `444` |


Congratulations. `Emily` is now logged in on `Alpha` and `Beta` by keeping up the session between `Firefox` and `Bouncer`. You could now proceed with logging in o `Gamma`, `Delta`, etc.

### Single-Sign-Out

This is simple. Just invalidate the Passport by setting the following flags.

###### Passports Table

| id       | ... | revoked_at         | revoke_reason |
|:---------|-----|:-------------------|:--------------|
| `aiaiai` | ... | `2015-12-24 21:00` | `logout`      |

Both `Alpha` and `Beta` know the passport ID so you could just create a logout link to `bouncer.dev/logout/aiaiai` and perform the revocation there.

Alternatively, `Alpha` could make a server-to-server request to `DELETE bouncer.dev/oauth/sso/v1/passports/aiaiai` and `Bouncer` executes the revocation then. In this scenario, `Emily` would not end up seeing `Bouncer` telling her "you are logged out", but `Alpha` being able to tell her so.

Which one you use depends on whichever is more desirable in your use case.

As soon as `Emily` makes subsequent requests to `Alpha`, the Passport verification request from `Alpha` to `Bouncer` will inform `Alpha` to delete the local Passport entirely. The same is true for `Beta`.

This way we effectively logged out every session which was created using `Firefox` but leave those alive which were created using e.g. `Safari`.

> Just a gentle recapitulation: if `Bouncer` is down, the logout will not work. So you better ensure it is up and running to minimize the exploitation window. As explained before, you could also log out every user whenever `Bouncer` does not respond. But then you really have a problem if someone succeeds DOSing `Bouncer`.

### Native Clients (aka iPhone/Android)

In essence, a native client is like any other OAuth Client. Yet there are a few differences:

1. This client needs to authenticate to other OAuth **Clients**, say, your API backend provided by `Alpha`.
2. There is **no way** you can hide **any** information on the device from the end user (this includes OAuth client credentials).
3. `Andoid` needs to read the plain Passport to display `Emilys` name in the app. Remember that, so far, the Passport was located in an encrypted `alpha.dev` cookie unintelligible to `Firefox`.

Also, we really want to avoid HTML web views for login forms. The whole point of native apps is to not have to fallback to browser technology.

The `iPhone` is known to `Bouncer` as a `Doorkeeper::Application`, but only the scope `outsider` is allowed for that application. The OAuth client credentials are hardcoded in the `iPhone` app code, and are considered public information (they can easily be extracted by the end-user).

So let's do this.

###### Logging in for the first time

It start's with the `iPhone` sending `Emilys` username and password to `Bouncer`.
In return, the `iPhone` will get an OAuth Access Token (this is the OAuth *Resource Owner Password Credentials Grant*). That Token is exchanged for a Passport.

Basically, the iPhone acts as both, `Firefox` and `Alpha`.

![](doc/iphone_comes_into_play.png?raw=true)

In the process, doorkeeper will create the access token and the `sso` gem helps you creating a new Passport which holds a reference to that access token.

###### Doorkeeper oauth_access_tokens Table

(Note: I omit any previous records here.
Anything that happened earlier only concerned the session between `Firefox` and `Bouncer`)

| id    | resource_owner_id | application_id | token    | scopes     |
|:------|------------------:|---------------:|:---------|:-----------|
| `555` |              `42` |   (iPhone) `3` | `5t5t5t` | `outsider` |

###### Passports Table

| id       | ... | oauth_access_grant_id | oauth_access_token_id |
|:---------|-----|----------------------:|----------------------:|
| `bibibi` | ... |                       |                 `555` |


Earlier, `Bouncer` trusted the `params` provided by `Alpha` to update the Passport IP meta information.
This time, `Bouncer` recognized that this is an `outsider` request and retrieves that information directly by inspecting the incoming `request.ip` object.

The `agent` and `device UUID`, however, are still retrieved from the `params`, since these are not reliable either way.

| id       | ... | ip              | agent    | location | device   |
|:---------|-----|:----------------|:---------|:---------|:---------|
| `bibibi` | ... | `198.51.100.22` | `iPhone` | `Venice` | `dedede` |

Now the `iPhone` has a Passport, `Emily` is logged in.

You probably want to persist the user information in some way, but the Passport `secret` should be persisted into secure storage (e.g. KeyChain). The Passport `secret` will typically not change. The user object will be updated more frequently (i.e. whenever the user state changes).

###### Cross-client authentication and authorization

Now let the `iPhone` use its Passport to request a resource from `Alpha`.

What does the `iPhone` have to offer to `Alpha` so that `Alpha` would trust, or even be able to verify the signature of the request? Nothing. Since `Alpha` does not even know the Passport `secret`, this would only be possible if `Alpha` would ask `Bouncer` about it.

If `Alpha` would have some (even unreliable) idea of what the `secret` is, `Alpha` could at least verify the signature of the `iPhone` request, and `Alpha` could then use that `secret` to sign the Passport verification request to `Bouncer`.

Do you remember the Passport `chip` attribute?
It's a synchronously encrypted data store which `Bouncer` creates and the `iPhone` cannot decipher.
If we introduce a simple shared secret between `Bouncer` and `Alpha`, we could "transport" some information from `Bouncer` to `Alpha`.
This is how the Passport `secret` will come to `Alpha`.

When `Bouncer` handed out the Passport to the `iPhone`, it performed the following operation to put something in the Passport `chip`. This value is not stored in any database, it is simply "attached" to the Passport.

```ruby
# Pseudo code of Bouncer setting the chip of the Passport
secret = "something only Bouncer, Alpha and Beta know (i.e. trusted clients)"
passport.chip = AES.encrypt(passport.secret).with(secret)
```

The `iPhone` simply passed on the `chip` to `Alpha`.
Upon receiving it, `Alpha` decrypts the chip and now knows the passport `secret`.
With that `secret`, `Alpha` is able to determine whether the `iPhone` properly signed the request with it.

Of course, `Alpha` **cannot trust** the `secret` (yet), but it is a practical approach for `Alpha` to be able to verify it with `Bouncer`.

So, the `iPhone` signs the request with the Passport `secret` and also sends along the Passport user `state` digest and the Passport `chip`.

![](doc/iphone_requests_alpha_resource.png?raw=true)

At this point, `Alpha` decrypts the `secret` from the `chip`, verifies the request and makes its own verification request to `Bouncer`.

Since this is the **first** request by `iPhone` to `Alpha`, `Alpha` has no information about `Emily` in some local datastore. So when `Alpha` makes its Passport verification request to `Bouncer`, it will simply omit the `state` so as to guarantee to receive a user object.

![](doc/alpha_verifies_iphone_passport.png?raw=true)

Now `Alpha` can persist the Passport, including the user, in its local data store (and ignore the `chip` from this point on). `Bouncer`, knowing that this

Any subsequent verification request from `Alpha` to `Bouncer` includes the `state` as usual. The response may not contain a user if the user `state` did not change meanwhile.

![](doc/alpha_verifies_iphone_passport_again.png?raw=true)

The response by `Bouncer` can even fail while `Alpha` will fallback to the previously verified Passport (along with all security implications previously explained).

![](doc/alpha_verifies_iphone_passport_fails.png?raw=true)

However, if it is the **first** time the `iPhone` talks to `Alpha`, the request from `Alpha` to `Bouncer` **must** succeed - in order to fetch a user. You need to be prepared for these kinds of errors in the `iPhone` app and retry or inform the user to try again later.

If the user object changed, `Alpha` informs the `iPhone` by delivering the new Passport `state` and `user` as a param (wait, how can Bouncer trust the params? Do we need to send in the insider_signature again?).

So to summarize, the `iPhone` always sends in Passport `id`, `state` and `chip` and any **trusted** OAuth client (`Alpha`, `Beta`) can receive this information at any time and get the authentication/authorization information from `Bouncer`.

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
