#
# Copyright:: Copyright (c) 2017 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef-workstation/log"
require "chef-workstation/error"
require "train"
module ChefWorkstation
  class TargetHost
    attr_reader :config, :reporter, :backend

    def self.instance_for_url(target, opts = {})
      target_host = new(target, opts)
      target_host.connect!
      target_host
    end

    def initialize(host_url, opts = {}, logger = nil)
      cfg = { target: host_url,
              sudo: opts.has_key?(:root) ? opts[:root] : true,
              www_form_encoded_password: true,
              key_files: opts[:identity_file],
              logger: ChefWorkstation::Log }
      if opts.has_key? :ssl
        cfg[:ssl] = opts[:ssl]
        cfg[:self_signed] = opts[:ssl_verify] == false ? true : false
      end

      @config = Train.target_config(cfg)
      @type = Train.validate_backend(@config)
      @train_connection = Train.create(@type, config)
    end

    def connect!
      if @backend.nil?
        @backend = @train_connection.connection
        @backend.wait_until_ready
      end
      nil
    end

    def hostname
      config[:host]
    end

    def platform
      backend.platform
    end

    def run_command!(command)
      result = backend.run_command command
      if result.exit_status != 0
        raise RemoteExecutionFailed.new(@config[:host], command, result)
      end
      result
    end

    def run_command(command)
      backend.run_command command
    end

    def upload_file(local_path, remote_path)
      backend.upload(local_path, remote_path)
    end

    class RemoteExecutionFailed < ChefWorkstation::ErrorNoLogs
      attr_reader :stdout, :stderr
      def initialize(host, command, result)
        super("CHEFRMT001",
              command,
              result.exit_status,
              host,
              result.stderr.empty? ? result.stdout : result.stderr)
      end
    end
  end
end
