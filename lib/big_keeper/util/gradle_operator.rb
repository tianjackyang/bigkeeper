require 'big_keeper/util/cache_operator'

module BigKeeper
  # Operator for podfile
  class GradleOperator
    def initialize(path)
      @path = path
    end

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
      cache_operator.clean
    end

    def update_settings_config(current_module_name, modules, user)
      CacheOperator.new(@path).load('settings.gradle')

      begin
        File.open("#{@path}/settings.gradle", 'a') do |file|
          modules.each do |module_name|
            next if current_module_name == module_name
            file.puts "\r\ninclude ':module:#{module_name.downcase}'\r\n"
            file.puts "project(':module:#{module_name.downcase}')." \
              "projectDir = new File(rootProject.projectDir," \
              "'#{BigkeeperParser.module_path(user, module_name)}/#{module_name.downcase}-lib')\r\n"
          end
        end
      ensure
      end
    end

    def update_build_config(current_module_name, modules, module_type, source)
      Dir.glob("#{@path}/*/build.gradle").each do |file|
        temp_file = Tempfile.new('.build.gradle.tmp')
        begin
          version_flag = false
          version_index = 0

          File.open(file, 'r') do |file|
            file.each_line do |line|
              modules.each do |module_name|
                next if current_module_name == module_name

                version_index, version_flag = generate_build_config(
                  line,
                  module_name,
                  module_type,
                  source,
                  version_index,
                  version_flag)
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

    def generate_build_config(line, module_name, module_type, source, version_index, version_flag)
      version_flag = true if line.downcase.include? 'modifypom'
      if version_flag
        version_index += 1 if line.include? '{'
        version_index -= 1 if line.include? '}'

        version_flag = false if 0 == version_flag

        temp_file.puts generate_version_config(line, module_name, module_type, source)
      else
        temp_file.puts generate_compile_config(line, module_name, module_type, source)
      end
      [version_index, version_flag]
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
        line.sub(/(\s*)version ('|")(\S*)('|")([\s\S]*)/){
          "#{$1}version '#{full_name}'#{$5}"
        }
      elsif ModuleType::SPEC == module_type
        line.sub(/(\s*)version ('|")(\S*)('|")([\s\S]*)/){
          "#{$1}version '#{source}'#{$5}"
        }
      else
        line
      end
    end

    def origin_config_of_module(module_name)
      origin_config = ''

      Dir.glob("#{@path}/.bigkeeper/*/build.gradle").each do |file|
        File.open(file, 'r') do |file|
          file.each_line do |line|
            if line =~ /(\s*)([\s\S]*)('|")(\S*):#{module_name.downcase}:(\S*)('|")(\S*)/
              origin_config = line
              break
            end
          end
        end
        break unless origin_config.empty?
      end

      origin_config.chop
    end

    def prefix_of_module(module_name)
      origin_config = origin_config_of_module(module_name)
      prefix = origin_config.sub(/(\s*)([\s\S]*)('|")(\S*)#{module_name.downcase}(\S*)('|")(\S*)/){
        $4
      }
      prefix.chop
    end

    def generate_compile_config(line, module_name, module_type, source)
      if ModuleType::PATH == module_type
        line.sub(/(\s*)compile(\s*)('|")(\S*):#{module_name.downcase}:(\S*)('|")(\S*)/){
          "#{$1}compile project(':module:#{module_name.downcase}')"
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
        line.sub(/(\s*)([\s\S]*)('|")(\S*):#{module_name.downcase}:(\S*)('|")(\S*)/){
          if $2.downcase.include? 'modulecompile'
            "#{$1}moduleCompile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{full_name}-SNAPSHOT'"
          else
            "#{$1}compile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{full_name}-SNAPSHOT'"
          end
        }
      elsif ModuleType::SPEC == module_type
        line.sub(/(\s*)([\s\S]*)('|")(\S*):#{module_name.downcase}:(\S*)('|")(\S*)/){
          if $2.downcase.include? 'modulecompile'
            "#{$1}moduleCompile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{source}'"
          else
            "#{$1}compile '#{prefix_of_module(module_name)}#{module_name.downcase}:#{source}'"
          end
        }
      else
        line
      end
    end

    private :generate_build_config, :generate_compile_config, :generate_version_config, :prefix_of_module
  end
end
