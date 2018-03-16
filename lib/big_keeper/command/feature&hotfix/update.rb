#!/usr/bin/ruby

require 'big_keeper/util/podfile_operator'
require 'big_keeper/util/gitflow_operator'
require 'big_keeper/util/bigkeeper_parser'
require 'big_keeper/util/logger'
require 'big_keeper/util/pod_operator'
require 'big_keeper/util/xcode_operator'
require 'big_keeper/util/cache_operator'

require 'big_keeper/dependency/dep_service'

require 'big_keeper/dependency/dep_type'

require 'big_keeper/service/stash_service'
require 'big_keeper/service/module_service'


module BigKeeper
  def self.update(path, user, modules, type)
    begin
      # Parse Bigkeeper file
      BigkeeperParser.parse("#{path}/Bigkeeper")
      branch_name = GitOperator.new.current_branch(path)

      Logger.error("Not a #{GitflowType.name(type)} branch, exit.") unless branch_name.include? GitflowType.name(type)

      full_name = branch_name.gsub(/#{GitflowType.name(type)}\//, '')

      current_modules = ModuleCacheOperator.new(path).all_path_modules

      # Verify input modules
      modules = BigkeeperParser.verify_modules(modules)

      Logger.highlight("Start to update modules for branch '#{branch_name}'...")

      add_modules = modules - current_modules
      del_modules = current_modules - modules

      ModuleCacheOperator.new(path).cache_path_modules(modules, add_modules, del_modules)
      modules = ModuleCacheOperator.new(path).remain_path_modules

      if add_modules.empty? and del_modules.empty?
        Logger.default("There is nothing changed with modules #{modules}.")
      else
        # Modify podfile as path and Start modules feature
        modules.each do |module_name|
          ModuleService.new.add(path, user, module_name, full_name, type)
        end

        del_modules.each do |module_name|
          ModuleService.new.del(path, user, module_name, full_name, type)
        end

        # Install
        DepService.dep_operator(path, user).install(false)

        # Open home workspace
        DepService.dep_operator(path, user).open
      end
    ensure
    end
  end
end
