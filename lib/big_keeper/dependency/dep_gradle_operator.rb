require 'big_keeper/dependency/dep_operator'

module BigKeeper
  # Operator for podfile
  class DepGradleOperator < DepOperator

    def backup
      cache_operator = CacheOperator.new(@path)
      cache_operator.save('settings.gradle')
      Dir.glob("#{@path}/*/build.gradle").each do |build_gradle_file_path|
        build_gradle_file = build_gradle_file_path.gsub!(/#{@path}/, '')
        cache_operator.save(build_gradle_file)
      end
    end

    def recover
      cache_operator = CacheOperator.new(@path)

      cache_operator.load('settings.gradle')
      # Dir.glob("#{@path}/*/build.gradle").each do |build_gradle_file_path|
      #   build_gradle_file = build_gradle_file_path.gsub!(/#{@path}/, '')
      #   cache_operator.load(build_gradle_file)
      # end

      cache_operator.clean
    end

    def modules_with_branch(modules, branch_name)
      full_name = branch_name.sub(/([\s\S]*)\/([\s\S]*)/){ $2 }
      file = "#{@path}/app/build.gradle"

      matched_modules = []
      File.open(file, 'r') do |file|
        file.each_line do |line|
          modules.each do |module_name|
            if line =~ /compile\s*('|")\S*#{module_name.downcase}:#{full_name}('|")\S*/
              matched_modules << module_name
              break
            end
          end
        end
      end
      matched_modules
    end

    def modules_with_type(modules, module_type)
      file = "#{@path}/app/build.gradle"

      matched_modules = []
      File.open(file, 'r') do |file|
        file.each_line do |line|
          modules.each do |module_name|
            if line =~ regex(module_type, module_name)
              matched_modules << module_name
              break
            end
          end
        end
      end
      matched_modules
    end

    def regex(module_type, module_name)
      if ModuleType::PATH == module_type
        /compile\s*project\(('|")\S*#{module_name.downcase}('|")\)\S*/
      elsif ModuleType::GIT == module_type
        /compile\s*('|")\S*#{module_name.downcase}\S*('|")\S*/
      elsif ModuleType::SPEC == module_type
        /compile\s*('|")\S*#{module_name.downcase}\S*('|")\S*/
      else
        //
      end
    end

    def update_module_config(module_name, module_type, source)
      Dir.glob("#{@path}/*/build.gradle").each do |file|
        temp_file = Tempfile.new('.build.gradle.tmp')
        begin
          version_flag = false
          version_index = 0

          File.open(file, 'r') do |file|
            file.each_line do |line|
              version_flag = true if line.include? 'modifyPom'
              if version_flag
                version_index += 1 if line.include? '{'
                version_index -= 1 if line.include? '}'

                version_flag = false if 0 == version_flag

                temp_file.puts generate_version_config(line, module_name, module_type, source)
              else
                temp_file.puts generate_compile_config(line, module_name, module_type, source)
              end
            end
          end
          temp_file.close
          FileUtils.mv(temp_file.path, file)
        ensure
          temp_file.close
          temp_file.unlink
        end
      end
    end

    def install(should_update, user)
      modules = modules_with_type(BigkeeperParser.module_names, ModuleType::PATH)

      CacheOperator.new(@path).load('settings.gradle')

      begin
        File.open("#{@path}/settings.gradle", 'a') do |file|
          modules.each do |module_name|
            file.puts "include ':#{module_name.downcase}'\r\n"
            file.puts "project(':#{module_name.downcase}')." \
              "projectDir = new File(rootProject.projectDir," \
              "'#{BigkeeperParser.module_path(user, module_name)}/#{module_name.downcase}-lib')\r\n"
          end
        end
      ensure
      end
    end

    def prefix_of_module(module_name)
      prefix = ''
      Dir.glob("#{@path}/.bigkeeper/*/build.gradle").each do |file|
        File.open(file, 'r') do |file|
          file.each_line do |line|
            if line =~ /(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/
              prefix = line.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
                $4
              }
              break
            end
          end
        end
        break unless prefix.empty?
      end

      prefix.chop
    end

    def open
    end

    def generate_version_config(line, module_name, module_type, source)
      if ModuleType::GIT == module_type
        branch_name = GitOperator.new.current_branch(@path)
        full_name = ''

        # Get version part of source.addition
        if 'develop' == source.addition || 'master' == source.addition
          full_name = branch_name.sub(/([\s\S]*)\/(\d+.\d+.\d+)_([\s\S]*)/){ $2 }
        else
          full_name = branch_name.sub(/([\s\S]*)\/([\s\S]*)/){ $2 }
        end
        line.sub(/(\s*)version ('|")(\S*)('|")(\s*)/){
          "#{$1}version ''"
        }
        line.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
          "#{$1}compile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{full_name}-SNAPSHOT'"
        }
      elsif ModuleType::SPEC == module_type
        line.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
          "#{$1}compile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{source}'"
        }
      else
        line
      end
    end

    def generate_compile_config(line, module_name, module_type, source)
      if ModuleType::PATH == module_type
        line.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
          "#{$1}compile project(':#{module_name.downcase}')"
        }
      elsif ModuleType::GIT == module_type
        branch_name = GitOperator.new.current_branch(@path)
        full_name = ''

        # Get version part of source.addition
        if 'develop' == source.addition || 'master' == source.addition
          full_name = branch_name.sub(/([\s\S]*)\/(\d+.\d+.\d+)_([\s\S]*)/){ $2 }
        else
          full_name = branch_name.sub(/([\s\S]*)\/([\s\S]*)/){ $2 }
        end
        line.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
          "#{$1}compile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{full_name}-SNAPSHOT'"
        }
      elsif ModuleType::SPEC == module_type
        line.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
          "#{$1}compile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{source}'"
        }
      else
        line
      end
    end

    private :generate_compile_config, :generate_version_config, :regex, :prefix_of_module
  end
end