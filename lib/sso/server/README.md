# Setting up an SSO server

### Assumptions

* You use doorkeeper as a Rails OAuth server.
* You want to provide single-sign-on for the end-users.
* All OAuth clients ("consumers") are developed by you. You have full control over them and can automatically trust them (i.e. you can set `skip_authorization { true }` in your doorkeeper.rb initializer). This makes sense, because why would you ask the end-user for permission to login to another subsystem of your SSO world? The whole idea with SSO is that your users don't need to notice switching between the OAuth clients.
* The SSO session is to be browser-wide and app-wide. If you click on "login" you will be logged in on every client web app in that browser. If you click on "logout" you will be logged out of every client web app in that browser.
* You use warden to login at the SSO server, it is, however, **not** okay to use scopes here. That's an assumption which makes this gem dramatically more simple and I didn't find a downside yet (Warden scopes are not really an ideal authorization solution anyway).

### Setup

For now, see [these point of interests](https://github.com/halo/sso/search?q=POI) to see how exactly a rails app can be setup.
