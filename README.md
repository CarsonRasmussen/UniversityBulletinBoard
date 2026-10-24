# University Bulletin Board

A campus bulletin board for university students to share events, clubs, announcements, and discussions.

**Author:** Carson Rasmussen  
**Course:** CS 408 — Full Stack Web Development  
**Live application:** http://18.237.129.155/

## Tech stack

Ruby on Rails, SQLite, ERB, Bootstrap, and AWS EC2 (Ubuntu), with nginx and systemd for hosting.

## Checkpoints

Each Git tag is a snapshot of the entire project at that checkpoint.

| Checkpoint | Features |
| --- | --- |
| [cp1](https://github.com/CarsonRasmussen/UniversityBulletinBoard/tree/cp1) | Rails setup, SQLite, Bootstrap, homepage, shared header, footer, and navigation. |
| [cp2](https://github.com/CarsonRasmussen/UniversityBulletinBoard/tree/cp2) | Database tables, student registration, university email verification, login/logout, basic EC2 deployment, and initial startup scripts. |

Checkpoint 2 includes tables for users, posts, comments, saved posts, and likes, with foreign keys and unique indexes. Post creation, image uploads, editing/deleting posts, search, comments, likes, and saved-post features are planned for later checkpoints. Their interface controls may be disabled in this version.

## Requirements

- Ruby **4.0.2** (see `.ruby-version`)
- Bundler (`gem install bundler`)
- Git and Bash; Windows users can use Git Bash
- On Linux: build tools and development headers for OpenSSL, YAML, zlib, and SQLite

Ruby and Bundler must be installed before running `start.sh`. The script installs application gems, prepares the database, and starts Rails.

## Run locally

```bash
git clone https://github.com/CarsonRasmussen/UniversityBulletinBoard.git
cd UniversityBulletinBoard
git checkout cp2
./start.sh
```

Open **http://localhost:3000**. Press **Ctrl + C** to stop the server.

To inspect Checkpoint 1, use `git checkout cp1`. Each tag contains its own version of the application and README. The instructions below describe Checkpoint 2.

## Student accounts

1. Open `/signup` and enter an `@boisestate.edu` or `@u.boisestate.edu` email address.
2. Choose a password of at least 12 characters and confirm it.
3. Open the verification link and click **Verify email**.
4. Sign in at `/login`. Use **Log out** to end the session.

Passwords are stored as bcrypt hashes. Unverified accounts cannot log in. Verification links expire after 24 hours and become invalid after verification. The login page includes a **Resend verification** form.

### Test verification locally without SMTP credentials

By default, development writes verification messages to `tmp/mails` instead of sending them. Open the generated message, copy its URL into your browser, and confirm verification.

This lets reviewers test the account flow without email credentials. It does not prove mailbox ownership; the live app uses SMTP delivery.

### Optional real email delivery on Windows

Use a Gmail account you control. Enable 2-Step Verification and create an [app password](https://myaccount.google.com/apppasswords). See [Google's requirements](https://support.google.com/mail/answer/185833).

Stop the existing Rails server. In **PowerShell**, from the project directory, run:

```powershell
.\script\start-with-email.ps1 -MailFrom "youraddress@gmail.com"
```

Enter the app password in the private credential prompt. The launcher uses Gmail SMTP with STARTTLS and passes credentials through process environment variables rather than saving them in the repository.

Open **http://localhost:3100**. Verification links use the same port. To choose another port:

```powershell
.\script\start-with-email.ps1 -MailFrom "youraddress@gmail.com" -Port 3200
```

Register or request a new verification email. Existing files in `tmp/mails` are not sent automatically. Open local verification links on the computer running Rails.

## Automated tests

```bash
bundle install
bundle exec rails db:prepare
bundle exec rails test
```

Tests cover the homepage, registration, accepted and rejected email domains, duplicate accounts, password confirmation, verification and expiration, resending, login/logout, and SMTP authentication failure handling. Tests do not send real emails.

Latest reported Checkpoint 2 result: **9 tests, 77 assertions, 0 failures, 0 errors**.

## EC2 deployment

The scripts target Ubuntu with an `ubuntu` user and install the app at `/var/www/university-bulletin-board`.

1. Allow SSH from your IP and web traffic on the required HTTP/HTTPS ports.
2. Copy the project to EC2 and run this on the server:

   ```bash
   sudo bash deploy/setup-ec2.sh
   ```

   This installs Ruby, Bundler, system dependencies, nginx, and the systemd service, and enables startup at boot.

3. Edit the server environment file:

   ```bash
   sudoedit /etc/bulletin-board.env
   ```

   Preserve the generated `SECRET_KEY_BASE` and add the settings from `deploy/bulletin-board.env.example`. Set `APP_HOST` to the public hostname or IP without a scheme or path. Configure the sender and SMTP credentials. Local email settings do not transfer automatically to EC2.

4. Configure a valid TLS certificate and nginx HTTPS support before setting `APP_PROTOCOL=https`. The included nginx configuration serves HTTP only. The current class demo uses HTTP: use a unique test password, and enable HTTPS before collecting real account credentials.

5. From the local project directory in Bash, deploy the checkpoint:

   ```bash
   git checkout cp2
   git status --short
   bash deploy/deploy.sh -h YOUR_EC2_HOST -i /path/to/key.pem
   ```

   Ensure the working tree is clean so the uploaded files match the tag. The deployment script runs tests, uploads code, installs gems, prepares databases, compiles assets, restarts Rails, and checks `/up`.

A successful health check does not confirm email delivery. Test signup, verification, login, and logout on the live site after deployment.

### Server checks

Run on EC2:

```bash
sudo systemctl status bulletin-board --no-pager
sudo journalctl -u bulletin-board -n 50 --no-pager
```

After changing the environment file, restart Rails:

```bash
sudo systemctl restart bulletin-board
```

To check automatic startup, run `sudo reboot`, wait for the instance to restart, reconnect, and check the service and website again.

## Configuration and data

- Keep `/etc/bulletin-board.env` root-owned with permissions `600`.
- Never commit app passwords, `.env` files, SSH private keys, or `config/master.key`.
- Exclude these files from shared ZIP archives too; `.gitignore` does not control manually created ZIPs.
- Back up `storage/` before migrations or deployment changes that affect data.
- Local and EC2 databases are separate. Local accounts do not automatically appear on the live site.
