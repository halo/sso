[![Join the chat at https://gitter.im/halo/sso](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/halo/sso)

The purpose of this gem is to do [this](https://github.com/halo/oauth-sso/blob/master/flow.pdf).

The code is already in use in production but needs to be extracted into this gem, which will happen very soon.


### Assumptions

* You use doorkeeper as an OAuth server.
* All OAuth clients ("consumers") are developed by you.

### Terminology

* Our **end user** is called `Carol`.
* Our **OAuth provider** we call `Bouncer` and it runs on the domain `bouncer.dev`.
  Just like at a nightclub, he knows *everything* about the end users.
* We will refer to `Alpha` and `Beta` as our **OAuth client web** applications running on the domains `alpha.dev` and `beta.dev`. These are *trusted* OAuth clients.
* `iPhone` and `Android` are our **mobile OAuth client** native applications. These are *untrusted* OAuth clients.


### Flow for trusted OAuth clients

* A trusted OAuth client, let's call it `Alpha`, uses the `Authorization Code Grant` to obtain an OAuth `access_token` with the OAuth permission scope `insider`.

* The browser of the end user actually "visits" `Bouncer` for the login. That's where the user is persisted into the session.



#### Unstrusted OAuth clients

* A public OAuth Client, such as an `iPhone`, uses the `Resource Owner Password Credentials Grant` to exchange the `username` and `password` of the end user for an OAuth `access_token` with the OAuth permission scope `outsider`.

### Step 2

#### Trusted OAuth clients


