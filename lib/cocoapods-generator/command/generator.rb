module Pod
  class Command
    # This is an example of a cocoapods plugin adding a top-level subcommand
    # to the 'pod' command.
    #
    # You can also create subcommands of existing or new commands. Say you
    # wanted to add a subcommand to `list` to show newly deprecated pods,
    # (e.g. `pod list deprecated`), there are a few things that would need
    # to change.
    #
    # - move this file to `lib/pod/command/list/deprecated.rb` and update
    #   the class to exist in the the Pod::Command::List namespace
    # - change this class to extend from `List` instead of `Command`. This
    #   tells the plugin system that it is a subcommand of `list`.
    # - edit `lib/cocoapods_plugins.rb` to require this file
    #

    class Generator < Command
      self.summary = 'add source files to project from podspec.'

      self.description = <<-DESC
        Add source files to existed project, which from podspec at current directory.
        Please Be Careful:
        1. Please make sure the **target** to be added equal to spec_name, else
        a target with spec_name will be created.
        2. Please make sure project name same to spec_name, else can't find *.xcodeproj file.
      DESC

      self.arguments = [CLAide::Argument.new('spec_name', true)]


      SPEC_SUBGROUPS = {
        :resources  => 'Resources',
        :frameworks => 'Frameworks',
      }

      ENABLE_OBJECT_USE_OBJC_FROM = {
        :ios => Version.new('6'),
        :osx => Version.new('10.8'),
        :watchos => Version.new('2.0'),
        :tvos => Version.new('9.0'),
      }

      SOURCE_FILE_EXTENSIONS = Sandbox::FileAccessor::SOURCE_FILE_EXTENSIONS

      def initialize(argv)
        @spec_name = argv.shift_argument
        @current_path = Dir.pwd
        @spec_path = @current_path + '/' + @spec_name if @current_path && @spec_name
        super
      end

      def validate!
        super

        if @spec_name.nil? || File.extname(@spec_name) != ".podspec"
          help! 'A *.podspec file is required.'
          Process.exit! false
        end
      end

      def run
        create_spec_content
        validatePodspec
        install
      end

      def validatePodspec
        linter = Specification::Linter.new(@spec_path)
        linter.lint
        results = []
        results.concat(linter.results.to_a)
        puts results_message results
      end

      def results_message(results)
        message = ''
        results.each do |result|
          if result.platforms == [:ios]
            platform_message = '[iOS] '
          elsif result.platforms == [:osx]
            platform_message = '[OSX] '
          elsif result.platforms == [:watchos]
            platform_message = '[watchOS] '
          elsif result.platforms == [:tvos]
            platform_message = '[tvOS] '
          end

          subspecs_message = ''
          if result.is_a?(Validator::Result)
            subspecs = result.subspecs.uniq
            if subspecs.count > 2
              subspecs_message = '[' + subspecs[0..2].join(', ') + ', and more...] '
            elsif subspecs.count > 0
              subspecs_message = '[' + subspecs.join(',') + '] '
            end
          end

          case result.type
          when :error   then type = 'ERROR'
          when :warning then type = 'WARN'
          when :note    then type = 'NOTE'
          else raise "#{result.type}" end
          message << "    - #{type.ljust(5)} | #{platform_message}#{subspecs_message}#{result.attribute_name}: #{result.message}\n"
        end
        message << "\n"
      end

      def create_spec_content
        @spec_content = Specification::from_file @spec_path
      end

      def xcodeproj_path
        project_path = File.expand_path File.basename(@spec_name, ".podspec") + '.xcodeproj', @current_path
        if !File.exists? project_path
          help! "Please make sure has #{File.basename project_path} in current directory."
          Process.exit! false
        end
        project_path
      end

      def add_framework_target_to_Xcodeproject
        project_path = xcodeproj_path
        podspec_consumer = consumer
        platform_name = consumer.platform_name
        deployment_target = podspec_consumer.spec.deployment platform_name
        target_name = @spec_name
        app_project = xcodeproj::Project.open project_path
        app_project.new_target('static_framework', target_name, platform_name, deployment_target)
        app_project.save
        app_project.recreate_user_schemes
        Xcodeproj::XCScheme.share_scheme(app_project.path, target_name)
      end

      def install
        project_path = xcodeproj_path
        @app_project = Xcodeproj::Project.open(project_path)
        @framework_target = @app_project.targets.find { |target| target.name == @spec_content.name }

        create_file_accessors
        add_source_files_references
        add_frameworks_bundles
        add_vendored_libraries
        add_resources

        add_files_to_build_phases
        add_libraries_to_build_phases

        @app_project.save
      end

      def create_file_accessors
        [@framework_target].each do |target|

          path_list = Sandbox::PathList.new(Pathname.new(Dir.new(@current_path)))
          specs = [@spec_content]
          specs.concat @spec_content.subspecs
          platform = Platform.new(target.platform_name, target.deployment_target)
          @file_accessors = specs.map do |spec|
            file_accessor = Sandbox::FileAccessor.new(path_list, spec.consumer(platform))
            file_accessor
          end
        end
      end

      def add_source_files_references
        add_file_accessors_paths_to_group(:source_files)
      end

      def add_frameworks_bundles
        add_file_accessors_paths_to_group(:vendored_frameworks, :frameworks)
      end

      def add_vendored_libraries
        add_file_accessors_paths_to_group(:vendored_libraries, :frameworks)
      end

      def add_resources
        add_file_accessors_paths_to_group(:resources, :resources)
        add_file_accessors_paths_to_group(:resource_bundle_files, :resources)
      end

      def add_file_accessors_paths_to_group(file_accessor_key, group_key = nil)
        @file_accessors.each do |file_accessor|
          pod_name = file_accessor.spec.name
          paths = file_accessor.send(file_accessor_key)
          paths = allowable_project_paths(paths)
          paths.each do |path|
            if !@app_project.reference_for_path(path)
              relative_pathname = path.relative_path_from(Pathname.new(@current_path))
              relative_dir = relative_pathname.dirname
              lproj_regex = /\.lproj/i
              group = group_for_spec(file_accessor.spec.name, group_key)
              relative_dir.each_filename do|name|
                break if name.to_s =~ lproj_regex
                next if name == '.'
                group = group[name] || group.new_group(name)
              end

              file_path_name = path.is_a?(Pathname) ? path : Pathname.new(path)
              ref = group.new_file(file_path_name.realpath)
            end
          end
        end
      end

      def group_for_spec(spec_name, subgroup_key = nil)
      if subgroup_key
        group_name = SPEC_SUBGROUPS[subgroup_key]
      else
        group_name = spec_name
      end

      @app_project[group_name] || @app_project.new_group(group_name)
      end

      def allowable_project_paths(paths)
        lproj_paths = Set.new
        lproj_paths_with_files = Set.new
        allowable_paths = paths.select do |path|
          path_str = path.to_s

          # We add the directory for a Core Data model, but not the items in it.
          next if path_str =~ /.*\.xcdatamodeld\/.+/i

          # We add the directory for a Core Data migration mapping, but not the items in it.
          next if path_str =~ /.*\.xcmappingmodel\/.+/i

          # We add the directory for an asset catalog, but not the items in it.
          next if path_str =~ /.*\.xcassets\/.+/i

          if path_str =~ /\.lproj(\/|$)/i
            # If the element is an .lproj directory then save it and potentially
            # add it later if we don't find any contained items.
            if path_str =~ /\.lproj$/i && path.directory?
              lproj_paths << path
              next
            end

            # Collect the paths for the .lproj directories that contain files.
            lproj_path = /(^.*\.lproj)\/.*/i.match(path_str)[1]
            lproj_paths_with_files << Pathname(lproj_path)

            # Directories nested within an .lproj directory are added as file
            # system references so their contained items are not added directly.
            next if path.dirname.dirname == lproj_path
          end

          true
        end

        # Only add the path for the .lproj directories that do not have anything
        # within them added as well. This generally happens if the glob within the
        # resources directory was not a recursive glob.
        allowable_paths + lproj_paths.subtract(lproj_paths_with_files).to_a
      end

      def add_files_to_build_phases
        @file_accessors.each do |file_accessor|
          consumer = file_accessor.spec_consumer

          headers = file_accessor.headers
          public_headers = file_accessor.public_headers
          private_headers = file_accessor.private_headers
          other_source_files = file_accessor.source_files.reject { |sf| SOURCE_FILE_EXTENSIONS.include?(sf.extname) }

          {
            true => file_accessor.arc_source_files,
            false => file_accessor.non_arc_source_files,
          }.each do |arc, files|
            files = files - headers - other_source_files
            flags = compiler_flags_for_consumer(consumer, arc)
            regular_file_refs = files.map { |sf| @app_project.reference_for_path(sf) }
            @framework_target.add_file_references(regular_file_refs, flags)
          end

          header_file_refs = headers.map { |sf| @app_project.reference_for_path(sf) }
          @framework_target.add_file_references(header_file_refs) do |build_file|
            add_header(build_file, public_headers, private_headers)
          end

          other_file_refs = other_source_files.map { |sf| @app_project.reference_for_path(sf) }
          @framework_target.add_file_references(other_file_refs, nil)

          resource_refs = file_accessor.resources.flatten.map do |res|
            @app_project.reference_for_path(res)
          end

          # Some nested files are not directly present in the Xcode project, such as the contents
          # of an .xcdatamodeld directory. These files will return nil file references.
          resource_refs.compact!

          @framework_target.add_resources(resource_refs)
        end
      end

      def add_libraries_to_build_phases
        file_accessor = @file_accessors.first
        @framework_target.add_system_framework(file_accessor.spec_consumer.frameworks)
        @framework_target.add_system_library(file_accessor.spec_consumer.libraries)

        add_vendored_library_to_build_phases(:vendored_frameworks)
        add_vendored_library_to_build_phases(:vendored_libraries)
      end

      def add_vendored_library_to_build_phases(sourcekey)
        file_accessor = @file_accessors.first
        file_accessor.send(sourcekey).each do |path|
          ref = @app_project.reference_for_path(path)
          if ref
            @framework_target.frameworks_build_phase.add_file_reference(ref)
          else
            help! "#{path.basename} no added to project!!"
          end
        end
      end

      def add_header(build_file, public_headers, private_headers)
        file_ref = build_file.file_ref
        acl = if public_headers.include?(file_ref.real_path)
                'Public'
              elsif private_headers.include?(file_ref.real_path)
                'Private'
              else
                'Project'
              end

        if header_mappings_dir && acl != 'Project'
          relative_path = file_ref.real_path.relative_path_from(header_mappings_dir)
          sub_dir = relative_path.dirname
          copy_phase_name = "Copy #{sub_dir} #{acl} Headers"
          copy_phase = native_target.copy_files_build_phases.find { |bp| bp.name == copy_phase_name } ||
            native_target.new_copy_files_build_phase(copy_phase_name)
          copy_phase.symbol_dst_subfolder_spec = :products_directory
          copy_phase.dst_path = "$(#{acl.upcase}_HEADERS_FOLDER_PATH)/#{sub_dir}"
          copy_phase.add_file_reference(file_ref, true)
        else
          build_file.settings ||= {}
          build_file.settings['ATTRIBUTES'] = [acl]
        end
      end

      def compiler_flags_for_consumer(consumer, arc)
        flags = consumer.compiler_flags.dup
        if !arc
          flags << '-fno-objc-arc'
        else
          platform_name = consumer.platform_name
          spec_deployment_target = consumer.spec.deployment_target(platform_name)
          if spec_deployment_target.nil? || Version.new(spec_deployment_target) < ENABLE_OBJECT_USE_OBJC_FROM[platform_name]
            flags << '-DOS_OBJECT_USE_OBJC=0'
          end
        end

        flags * ' '
      end

      def header_mappings_dir
        file_accessor = @file_accessors.first
        header_mappings_dir = if dir = file_accessor.spec_consumer.header_mappings_dir
                                 file_accessor.path_list.root + dir
                               end
      end

    end
  end
end
