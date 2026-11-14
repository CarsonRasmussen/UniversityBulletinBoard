# University Bulletin Board

A campus bulletin board for university students to share events, clubs, announcements, and discussions.

**Author:** Carson Rasmussen  
**Course:** CS 408 — Full Stack Web Development  
**Application address:** http://18.237.129.155/

Checkpoint 5 is implemented in the working version; its live deployment has not been verified.

## Tech stack

Ruby on Rails, SQLite, ERB, Bootstrap, and AWS EC2 (Ubuntu), with nginx and systemd for hosting.

## Checkpoints

Each Git tag is a snapshot of the entire project at that checkpoint.

| Checkpoint | Features |
| --- | --- |
| [cp1](https://github.com/CarsonRasmussen/UniversityBulletinBoard/tree/cp1) | Rails setup, SQLite, Bootstrap, homepage, shared header, footer, and navigation. |
| [cp2](https://github.com/CarsonRasmussen/UniversityBulletinBoard/tree/cp2) | Database tables, student registration, university email verification, login/logout, basic EC2 deployment, and initial startup scripts. |
| [cp3](https://github.com/CarsonRasmussen/UniversityBulletinBoard/tree/cp3) | Create posts, optional JPEG/PNG/WebP uploads, public posts list and details, and recent homepage posts. |
| [cp4](https://github.com/CarsonRasmussen/UniversityBulletinBoard/tree/cp4) | Edit and delete your own posts, with controller permissions and optional image replacement/removal. |
| Checkpoint 5 (working version, not tagged) | Search, category filters, comments, likes, popular posts, and personal saved/liked lists. |

The current version includes Checkpoints 1–5. The homepage shows the four most-liked posts, with newer posts first when like counts tie.

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
./start.sh
```

Open **http://localhost:3000**. Press **Ctrl + C** to stop the server.

If port 3000 is occupied, run `PORT=3100 ./start.sh` in Bash. The server and
local verification links will both use port 3100.

To inspect a previous checkpoint, use `git checkout cp1`, `git checkout cp2`, or `git checkout cp3` with a clean working tree. Each tag contains its own version of the application and README. The instructions below describe the current working version.

## Student accounts

1. Open `/signup` and enter an `@boisestate.edu` or `@u.boisestate.edu` email address.
2. Choose a password of at least 12 characters and confirm it.
3. Open the verification link and click **Verify email**.
4. Sign in at `/login`. Use **Log out** to end the session.

Passwords are stored as bcrypt hashes. Unverified accounts cannot log in. Verification links expire after 24 hours and become invalid after verification. The login page includes a **Resend verification** form.

### Test verification locally without SMTP credentials

By default, development writes verification messages to `tmp/mails` instead of sending them. Open the generated message, copy its URL into your browser, and confirm verification.

This lets reviewers test the account flow without email credentials. It does not prove mailbox ownership; production is configured to use SMTP delivery.

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
RAILS_ENV=test bundle exec rails db:prepare
bundle exec rails test
```

Tests cover student accounts, email delivery failures, post creation permissions, required fields, category validation, image uploads and retrieval, invalid images, escaped post content, and pagination. Checkpoint 4 adds direct-request authorization checks, successful and failed edits, image retention/replacement/removal, and deletion with dependent-record and upload cleanup. Tests do not send real emails.

Checkpoint 3 local validation: **27 tests, 456 assertions, 0 failures, 0 errors**.

Checkpoint 4 local validation: **38 tests, 588 assertions, 0 failures, 0 errors**.

Checkpoint 5 local validation: **48 tests, 774 assertions, 0 failures, 0 errors**.
New coverage includes combined search/filter pagination, literal wildcard searches,
like-based ranking, comment validation and escaping, verified-account enforcement,
author spoofing prevention, duplicate likes/saves, and private saved/liked lists.
Ruby style checks passed (51 files); Brakeman reported no security warnings.

Additional local checks used an isolated source copy without existing databases,
uploads, or credentials: `./start.sh` prepared the database and served `/posts`;
the full tests passed; upgrading populated Checkpoint 2 tables preserved the
account, post, and legacy image value. A saved upload survived extracting a
deployment package over the app and starting a new Rails process. Production
`db:prepare`, asset compilation, and boot passed with test-only environment
settings. These checks ran on Windows with Git Bash; they do not establish
successful deployment or email delivery on EC2.

## Campus posts (Checkpoint 3)

1. Browse `/posts` to see the newest posts, 12 per page. Open a title to read the full post.
2. Log in with a verified student account, then choose **Create Post**.
3. Enter a title (up to 150 characters), description (up to 10,000 characters), and category.
4. Optionally choose a JPG, PNG, or WebP image up to 5 MB, then click **Create post**.

Errors preserve your text; choose the image again after a failed submission.
Posts display the author's name rather than their email address. Only verified,
logged-in accounts can publish; visitors can browse. Images use Rails Active
Storage and remain in `storage/` across application restarts. Back up this folder
along with the database. The old text image column is preserved as `legacy_image`;
new uploads use Active Storage attachments.

Categories are **Events**, **Clubs**, **Announcements**, and **Discussions**.
The homepage retains its existing layout and showed the four newest database
posts in the Checkpoint 3 snapshot. Checkpoint 5 adds search, filters, comments,
likes, and saves, and ranks homepage posts by likes.

Run `bundle exec rails db:prepare` after updating to install the new tables.

## Manage your posts (Checkpoint 4)

1. Log in with the verified account that created the post and open its detail page.
2. Choose **Edit post** to update the title, description, or category. Leave the
   image field blank to keep the current image, select a replacement, or check
   **Remove current image**. A replacement takes priority if both are selected.
3. Choose **Save changes**. Validation errors keep entered text and leave the
   saved post and its original image intact. Reselect a replacement file after
   an invalid submission. **Cancel** returns to the post without saving.
4. Choose **Delete post** and confirm the browser prompt to permanently delete
   the post. Deletion also removes dependent comments, likes, and saves. Active
   Storage queues cleanup of the uploaded image through the configured job adapter.

   In production, run a Solid Queue worker for image analysis and cleanup.
   On the existing single-server EC2 setup, add `SOLID_QUEUE_IN_PUMA=true` to
   `/etc/bulletin-board.env`, then restart `bulletin-board`. The existing Puma
   configuration starts the worker when that setting is enabled.

Only the author sees these controls. The controller also blocks another user's
direct edit, update, or delete requests with a 403 response. Guests and accounts
whose email verification has been revoked must log in with a verified account.
Authors cannot be changed through submitted parameters. Browsing stays public.
Checkpoint 4 requires no additional database migrations.

To manually check permissions, create a post with one account, then sign in
with a second verified account and try opening `/posts/POST_ID/edit`. It should
be forbidden. Try editing with a missing required field to confirm the original
post is preserved, then save a valid change and delete a test post.

## Discover and interact (Checkpoint 5)

- Search titles and descriptions from the homepage or **Search** navigation link.
  Searches match a literal phrase (up to 200 characters); ordinary English text
  matches regardless of capitalization. `%` and `_` are treated as literal text.
- Choose **Events**, **Clubs**, **Announcements**, or **Discussions** to filter.
  Search and category can be combined; **All posts** clears the category while
  keeping the search. Clear the search field and submit to remove the search.
  Results are newest first, 12 per page, and filters persist across pages.
- The homepage shows four **Popular on campus** posts ranked by total likes.
  Ties use newest creation time, then post ID. Posts with no likes remain eligible.
- Open a post and log in with a verified student account to comment (1 to 2,000
  characters), like/unlike, or save/unsave it. Comments are publicly visible in
  creation order and display names rather than email addresses. Invalid comments
  show errors and preserve entered text. User content is rendered as text.
- **Saved** and **Liked** in the navigation show only your own collection, newest
  posts first, 12 per page. Open a post to remove its like or save. These actions
  never remove another account's like or save. Repeated requests do not add duplicates.
- Guests can browse/search and read comments; interacting and viewing personal
  lists requires verified login. Comment authors come from the session and post
  IDs from the route, not submitted identity fields.

This checkpoint uses existing tables and requires no new migrations or services.
Existing upload storage, email settings, and deployment scripts remain applicable.

Run the full suite with `bundle exec rails test`, or only the new coverage with:

```bash
bundle exec rails test test/integration/post_discovery_test.rb test/integration/post_interactions_test.rb
```

For a manual check, run `./start.sh` in Bash, create posts in two categories,
search by a word in a description, and combine the search with a category. Log in,
comment and like/save a post, then check **Saved**, **Liked**, and the homepage.
Use a second account to confirm its personal lists are separate. Unlike/unsave
and confirm the first account's other records remain intact. Log out and verify
browsing still works while interaction controls request login.

For EC2, follow the existing update instructions below, then perform these same
checks on the live site. No Checkpoint 5 deployment or live email test has been
performed here; deployment and checkpoint tagging remain separate steps.

## EC2 deployment

The scripts target Ubuntu with an `ubuntu` user and install the app at `/var/www/university-bulletin-board`.
For an existing server, use the update steps below. Do not rerun initial setup
over a customized nginx/HTTPS configuration.

### First-time server setup

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

### Update an existing EC2 installation for Checkpoints 3–5

1. Connect to the server:

   ```bash
   ssh -i /path/to/key.pem ubuntu@YOUR_EC2_HOST
   ```

2. Back up the database and uploaded images together before migrating:

   ```bash
   sudo install -d -m 700 /var/backups/bulletin-board
   sudo systemctl stop bulletin-board
   sudo tar -czf "/var/backups/bulletin-board/storage-$(date +%Y%m%d-%H%M%S).tar.gz" \
     -C /var/www/university-bulletin-board storage
   sudo systemctl start bulletin-board
   ```

   If the backup fails, fix it before deploying. Keep the existing
   `/etc/bulletin-board.env` and `SECRET_KEY_BASE`.

3. On EC2, run `sudoedit /etc/nginx/sites-available/bulletin-board` and add
   `client_max_body_size 6m;` inside the app's existing server block (including
   its HTTPS server block, if configured). Preserve its other settings:

   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

4. From the local project directory in Bash, deploy the reviewed working version:

   ```bash
   git status --short
   bash deploy/deploy.sh -h YOUR_EC2_HOST -i /path/to/key.pem
   ```

   The script uploads the working directory. Review `git status --short` first;
   a checkpoint tag is not created by deployment. It prepares the test database,
   runs tests, uploads code, installs gems, applies migrations, compiles assets,
   restarts Rails, and checks `/up` while following HTTP/HTTPS redirects.

   A successful health check does not confirm email delivery. Test signup,
   verification, login, and logout on the live site after deployment.

5. Browse `/posts` as a visitor, then log in with a verified student account.
   Create one post without an image and one with an image. Confirm the author,
   category, creation date, text, image, and homepage links. Restart the service
   and verify that the uploaded image is still visible. Check it again after
   the next deployment.

   For Checkpoint 4, edit a post as its author and confirm a second account
   cannot edit it. Delete a test post and confirm it disappears from the list,
   homepage, and detail URL. These live checks have not been performed here.

The archive is built by `deploy/package.sh`. It excludes local `storage/`,
databases, logs, temporary files, environment files, AWS configuration, and keys.
Extraction updates the existing app directory without deleting server storage.
The production disk service uses that same `storage/` directory, so both uploads
and SQLite databases survive normal restarts and these in-place deployments.
This does not protect against replacing the EC2 disk or deleting storage; keep
backups. Local changes do not update EC2 automatically.

To inspect a package without deploying:

```bash
bash deploy/package.sh /tmp/bulletin-board-review.tar.gz
tar -tzf /tmp/bulletin-board-review.tar.gz
```

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
