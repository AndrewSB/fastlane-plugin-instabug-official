require 'fileutils'
require 'fastlane/action'
require_relative '../helper/instabug_official_helper'

module Fastlane
  module Actions
    class InstabugOfficialAction < Action
      def self.run(params)
        api_token = params[:api_token]

        endpoint = 'https://api.instabug.com/api/sdk/v3/symbols_files'
        command = "curl #{endpoint} --write-out %{http_code} --silent --output /dev/null -F os=\"ios\" -F application_token=\"#{api_token}\" -F symbols_file="

        curlCommand = ''
        single_path = params[:dsym_path]

        if !single_path.nil?
          curlCommand += build_single_file_command(command, single_path)
        else
          dsym_paths = params[:dsym_array_paths].uniq

          directory_name = generate_directory_name
          copy_dsym_paths_into_directory(dsym_paths, directory_name)
          build_single_file_command(command, dsym_paths)
          remove_directory(directory_name)
        end

        UI.verbose curlCommand
        return curlCommand if Helper.test?

        result = Actions.sh(curlCommand)
        if result == '200'
          UI.success 'dSYM is successfully uploaded to Instabug 🤖'
        else
          UI.error "Something went wrong during Instabug dSYM upload. Status code is #{result}"
        end
      end

      def self.description
        'upload dsyms to fastlane'
      end

      def self.authors
        ['Karim_Mousa_89']
      end

      def self.return_value
          # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        'upload dsyms to fastlane'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: 'FL_INSTABUG_API_TOKEN', # The name of the environment variable
                                       description: 'API Token for Instabug', # a short description of this parameter
                                       verify_block: proc do |value|
                                                       UI.user_error!("No API token for InstabugAction given, pass using `api_token: 'token'`") unless value && !value.empty?
                                                     end),
          FastlaneCore::ConfigItem.new(key: :dsym_array_paths,
                                       type: Array,
                                       optional: true,
                                       description: 'Array of paths to *.dSYM.zip files',
                                       default_value: Actions.lane_context[SharedValues::DSYM_PATHS]),
          FastlaneCore::ConfigItem.new(key: :dsym_path,
                                       env_name: 'FL_INSTABUG_DSYM_PATH',
                                       description: 'Path to *.dSYM file',
                                       default_value: Actions.lane_context[SharedValues::DSYM_OUTPUT_PATH],
                                       is_string: true,
                                       optional: true,
                                       verify_block: proc do |value|
                                                       UI.user_error!("dSYM file doesn't exists") unless File.exist?(value)
                                                     end)
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
        true
      end

      private

      def self.generate_directory_name
        "Instabug_dsym_files_fastlane_#{Time.now.to_i}"
      end

      def self.remove_directory(directory_path)
        FileUtils.rm_rf directory_path
      end

      def self.copy_dsym_paths_into_directory(dsym_paths, directory_path)
        remove_directory(directory_name)
        FileUtils.mkdir_p directory_path
        dsym_paths.each do |path|
          File.copy(path, "#{directory_path}/#{path}")
        end
      end

      def self.build_single_file_command(command, dsym_path)
        file_path = if dsym_path.end_with?('.zip')
                      dsym_path.shellescape
                    else
                      ZipAction.run(path: dsym_path).shellescape
                    end
        command + "@\"#{file_path}\""
      end
    end
  end
end
