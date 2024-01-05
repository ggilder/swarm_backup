#!/usr/bin/env ruby

# Allows the script to work (i.e. load Bundler dependencies) even when run from
# a different working directory
Dir.chdir(File.dirname(File.realpath(__FILE__)))

require "rubygems"
require "bundler"

Bundler.require

require "fileutils"
require "cgi"
require "open3"
require "time"

def new_git_repo(repo)
  repo.object('HEAD')
  return false
rescue Git::GitExecuteError
  return true
end

def git_repo_dirty(repo)
  if new_git_repo(repo)
    repo.lib.ls_files(%w(-o --exclude-standard)).count > 0
  else
    repo.status.untracked.count > 0 ||
      repo.status.changed.count > 0 ||
      repo.status.added.count > 0 ||
      repo.status.deleted.count > 0
  end
end

######################### Execution ######################

no_commit = ARGV.delete("--no-commit")

backup_destination = ARGV.shift
if !backup_destination || !File.directory?(backup_destination) || !File.writable?(backup_destination)
  $stderr.puts "Backup destination must be a writable directory!"
  exit 1
end

git_dir = File.join(backup_destination, ".git")
git_repo = if !File.directory?(git_dir)
  puts "Git repository not present in backup destination; initializing"
  Git.init(backup_destination)
else
  Git.open(backup_destination)
end

# Fail if any pre-existing changes
if git_repo_dirty(git_repo)
  puts "Repo is not in a clean state!"
  exit(1)
end

begin
  puts "Backing up checkins..."
  exit_status = Open3.popen2e("./swarm_backup", "--output", backup_destination) do |input, out_and_err, wait_thr|
    out_and_err.each do |line|
      print(line)
    end

    wait_thr.value
  end
  unless exit_status.success?
    raise "Backup failed!"
  end

  # Work around bug with cached index in git gem
  begin
    git_repo.lib.send(:command_lines, 'update-index', ['--refresh'])
  rescue
    # The update-index command can fail, no big deal
  end

  puts
  puts "Status:"
  if new_git_repo(git_repo)
    puts "(new repo, no status to show)"
  else
    puts "New: #{git_repo.status.untracked.count}"
    puts "Changed: #{git_repo.status.changed.count}"
    puts "Deleted: #{git_repo.status.deleted.count}"
  end

  puts
  if git_repo_dirty(git_repo)
    if no_commit
      puts "Skipping commit and push; --no-commit flag given."
    else
      puts "Committing latest backup"
      git_repo.add(all: true)
      git_repo.commit("Backup")
      puts "Pushing changes"
      git_repo.push
    end
  else
    puts "No changes to commit."
  end

  puts
  puts "Backup completed!"

rescue StandardError => e
  git_repo.reset_hard
  git_repo.clean(force: true)
  $stderr.puts e
  $stderr.puts e.backtrace.join("\n")
  $stderr.puts "Reset repo to clean state."
  exit 1
end
