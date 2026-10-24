# University Bulletin Board

## Requirements
- Ruby 4.0.2
- Bundler (`gem install bundler`)
- Bash
- On Linux: build tools and development headers for OpenSSL,
  YAML, zlib, and SQLite to install Ruby and native gems.

## Run
./start.sh

Open http://localhost:3000

The script installs project dependencies, prepares the database,
and starts the application.

## Checkpoint 2

Registration at `/signup` accepts `@boisestate.edu` and `@u.boisestate.edu`. Passwords require at
least 12 characters and are stored as bcrypt hashes. Students must verify their
email before logging in. Verification links expire after 24 hours and become
invalid after use. `/login` also offers verification email resending.

In development, verification emails are written to `tmp/mails`. Open the URL
in the email file, confirm verification, then log in. This tests the flow locally;
production requires real SMTP delivery to prove mailbox ownership.

### Send real emails locally

Sign into `universitybulletinboard@gmail.com`, enable Google 2-Step
Verification, and create an app password at https://myaccount.google.com/apppasswords.
App passwords may be unavailable for some managed accounts or security settings.
Use the generated app password rather than your normal Google password.
See https://support.google.com/mail/answer/185833 for Google's requirements.

Stop the existing Rails server, then run this from PowerShell:

```powershell
.\script\start-with-email.ps1
```

The script defaults to Gmail SMTP (`smtp.gmail.com:587` with STARTTLS) and
`universitybulletinboard@gmail.com` as both the sender and username.
It prompts for the app password with the username already filled in.
The password is entered through a credential prompt, passed to Rails through
the process environment, and never saved in the repository. It starts at
`http://localhost:3100`; verification links use that same port. You may pass
`-Port 3200` to use a different port. Register or resend verification to test
delivery. Existing verification email files will not be sent automatically.

Without SMTP settings, development continues saving mail in `tmp/mails`.
Tests never send real emails. Students still register with their Boise State
email addresses; the Gmail account only sends the verification messages.

The database foundation includes users, posts, comments, saved posts and likes,
with foreign keys and unique indexes for email addresses and user/post pairs.
Post features are scheduled for later checkpoints.

Run `bundle install`, `bundle exec rails db:prepare`, then
`bundle exec rails test` to check the application.

## Basic EC2 deployment

Use an Ubuntu EC2 instance with SSH access restricted to your IP. Allow web
traffic on ports 80 and 443. Use HTTPS before collecting real passwords.

1. Copy the repository to the instance and run
   `sudo bash deploy/setup-ec2.sh`. This installs Ruby, nginx and the systemd
   service, and enables the service to start at boot.
2. Edit `/etc/bulletin-board.env` with `sudoedit`. Keep the generated
   `SECRET_KEY_BASE` and add the settings in `deploy/bulletin-board.env.example`.
   Use your SMTP provider's credentials and an authorized sender address.
   Set `APP_HOST` to the public hostname (without a scheme or path).
3. Configure TLS on nginx for that hostname; the included nginx configuration
   is an HTTP starting point. `APP_PROTOCOL=https` enables Rails HTTPS redirects
   and secure session cookies. For an initial HTTP smoke check only, set it to
   `http`; do not use real account credentials over HTTP.
4. From a Bash environment with Ruby/Bundler installed, run
   `bash deploy/deploy.sh -h PUBLIC-HOST -i /path/to/key.pem`.
   It runs tests, uploads code, prepares databases, compiles assets and restarts
   the service. Check `/up` and register using a real Boise State mailbox.
5. On EC2, run `sudo reboot`, reconnect and check
   `sudo systemctl status bulletin-board` and the site. For errors use
   `sudo journalctl -u bulletin-board -n 50 --no-pager`.

The environment file contains secrets: keep it root-owned with mode 600.
Back up `storage/` before future migrations or deployments. A live deployment,
SMTP delivery and reboot still need verification against your actual EC2 instance.
