# swarm\_backup

## Backup Swarm checkins

This script backs up your Swarm checkins. It uses git to maintain revision history in the backup directory, just for fun.

Currently, backing up photos attached to checkins is not supported.

## Usage

1. View the Swarm web site and use web inspector to view the XHR requests it makes. Copy the values for `wsid`, `oauth_token`, and `user_id` to `credentials.json` following the example file.
2. Compile the Swift portion: `swiftc swarm_backup.swift`
3. Run `bundle install`
4. Run: `./backup_swarm.rb BACKUP_DESTINATION_DIRECTORY`
