require 'big_keeper/util/logger'

module BigKeeper
  # Operator for got
  class GitOperator
    def current_branch(path)
      Dir.chdir(path) do
        `git rev-parse --abbrev-ref HEAD`.chop
      end
    end

    def has_remote_branch(path, branch_name)
      has_branch = false
      IO.popen("cd #{path}; git branch -r") do |io|
        io.each do |line|
          has_branch = true if line =~ /([\s\S]*)#{branch_name}$/
        end
      end
      has_branch
    end

    def has_local_branch(path, branch_name)
      has_branch = false
      IO.popen("cd #{path}; git branch") do |io|
        io.each do |line|
          has_branch = true if line =~ /([\s\S]*)#{branch_name}$/
        end
      end
      has_branch
    end

    def has_branch(path, branch_name)
      has_branch = false
      IO.popen("cd #{path}; git branch -a") do |io|
        io.each do |line|
          has_branch = true if line =~ /([\s\S]*)#{branch_name}$/
        end
      end
      has_branch
    end

    def checkout(path, branch_name)
      Dir.chdir(path) do
        IO.popen("git checkout #{branch_name}") do |io|
          io.each do |line|
            Logger.error("Checkout #{branch_name} failed.") if line.include? 'error'
          end
        end
      end
    end

    def fetch(path)
      Dir.chdir(path) do
        `git fetch origin`
      end
    end

    def rebase(path, branch_name)
      Dir.chdir(path) do
        `git rebase origin/#{branch_name}`
      end
    end

    def clone(path, git_base)
      Dir.chdir(path) do
        `git clone #{git_base}`
      end
    end

    def commit(path, message)
      Dir.chdir(path) do
        `git add .`
        `git commit -m "#{message}"`
      end
    end

    def push_to_remote(path, branch_name)
      Dir.chdir(path) do
        `git push -u origin #{branch_name}`
      end
    end

    def pull(path)
      Dir.chdir(path) do
        `git pull`
      end
    end

    def has_commits(path, branch_name)
      has_commits = false
      IO.popen("cd #{path}; git log #{branch_name} --not --remotes") do |io|
        io.each do |line|
          has_commits = true if line.include? branch_name
        end
      end
      has_commits
    end

    def has_changes(path)
      has_changes = true
      clear_flag = 'nothing to commit, working tree clean'
      IO.popen("cd #{path}; git status") do |io|
        io.each do |line|
          has_changes = false if line.include? clear_flag
        end
      end
      has_changes
    end

    def discard(path)
      Dir.chdir(path) do
        `git checkout . && git clean -xdf`
      end
    end

    def del_local(path, branch_name)
      Dir.chdir(path) do
        `git branch -D #{branch_name}`
      end
    end

    def del_remote(path, branch_name)
      Dir.chdir(path) do
        `git push origin --delete #{branch_name}`
      end
    end

    def user
      `git config user.name`.chop
    end

    def tag(path, version)
      Dir.chdir(path) do
        `git tag -a #{version} -m "release: V #{version}" master`
        `git push --tags`
      end
    end
  end

  # p GitOperator.new.user
  # BigStash::StashOperator.new("/Users/mmoaay/Documents/eleme/BigKeeperMain").list
end
