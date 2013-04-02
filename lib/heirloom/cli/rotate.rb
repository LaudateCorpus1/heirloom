module Heirloom
  module CLI
    class Rotate

      include Heirloom::CLI::Shared

      def initialize
        @opts = read_options
        @logger = HeirloomLogger.new :log_level => @opts[:level]
        @config = load_config :logger => @logger,
                              :opts   => @opts

        ensure_valid_options :provided => @opts,
                             :required => [:name],
                             :config   => @config

        @catalog = Heirloom::Catalog.new :name    => @opts[:name],
                                         :config  => @config

        # Can't use fetch as Trollop sets :id to nil
        id = @opts[:id] ||( latest_id :name   => @opts[:name],                                              
                                      :config => @config)

        @archive = Archive.new :name   => @opts[:name],
                               :config => @config,
                               :id     => id

        unless @opts[:bucket_prefix]
          ensure_archive_exists :archive => @archive,
                                :config  => @config
        end

        # Lookup region & bucket_prefix from simpledb unless specified
        # To Do, valid validation message that simpledb exists
        @region = @opts[:region] || @catalog.regions.first
        @bucket_prefix = @opts[:bucket_prefix] || @catalog.bucket_prefix
      end
      
      def rotate
        ensure_path_is_directory     :path => @opts[:output], :config => @config
        ensure_directory_is_writable :path => @opts[:output], :config => @config
        secret = read_secret :opts   => @opts,
                             :config => @config
        archive = @archive.download :output        => @opts[:output],
                                    :extract       => @opts[:extract],
                                    :region        => @region,
                                    :bucket_prefix => @bucket_prefix,
                                    :secret        => secret
        # do rotation
        exit 1 unless archive
      end

      private

      def read_options
        Trollop::options do
          version Heirloom::VERSION
          banner <<-EOS

Rotate keys for an Heirloom.  

Will download the heirloom to temp directory, decrypt, encrypt, and upload, replacing original.

Usage:

heirloom rotate -n NAME -i ID -s NEW_SECRET -o OLD_SECRET

To rotate Heirloom without looking up details in SimpleDB, specify region (-r), ID (-i) and bucket_prefix (-b) options.

EOS
          opt :bucket_prefix, "Bucket prefix of the Heirloom to download.", :type => :string
          opt :extract, "Extract the Heirloom into the given output path.", :short => "-x"
          opt :help, "Display Help"
          opt :id, "ID of the Heirloom to download.", :type => :string
          opt :level, "Log level [debug|info|warn|error].", :type    => :string,
                                                            :default => 'info'
          opt :metadata_region, "AWS region to store Heirloom metadata.", :type    => :string,
                                                                          :default => 'us-west-1'
          opt :name, "Name of Heirloom.", :type => :string
          opt :region, "Region to download Heirloom.", :type    => :string,
                                                       :default => 'us-west-1'
          opt :secret, "New Secret for ecrypted Heirloom.", :type => :string
          opt :secret_file, "Read secret from file.", :type  => :string,
                                                      :short => :none
          opt :old_secret, "Old secret for ecrypted Heirloom.", :type => :string
          opt :old_secret_file, "Read old secret from file.", :type => :string,
                                                              :short => :none
          opt :aws_access_key, "AWS Access Key ID", :type => :string, 
                                                    :short => :none
          opt :aws_secret_key, "AWS Secret Access Key", :type => :string, 
                                                        :short => :none
        end
      end
    end
  end
end
