require 'mkmf'
module DockerSync
  module Preconditions
    class Osx
      def check_all_preconditions(config)
        return unless should_run_precondition?

        docker_available
        docker_running

        if config.unison_required?
          unison_available
        end

        if config.rsync_required?
          rsync_available
          fswatch_available
        end
      end

      def docker_available
        if (find_executable0 'docker').nil?
          raise('Could not find docker binary in path. Please install it, e.g. using "brew install docker" or install docker-for-mac')
        end
      end

      def docker_running
        `docker ps`
        if $?.exitstatus > 0
          raise('No docker daemon seems to be running. Did you start your docker-for-mac / docker-machine?')
        end
      end

      def rsync_available
        if should_run_precondition?
          if (find_executable0 'rsync').nil?
            raise('Could not find rsync binary in path. Please install it, e.g. using "brew install rsync"')
          end
        end
      end

      def unison_available
        if should_run_precondition?
          if (find_executable0 'unison').nil?
            cmd1 = 'brew install unison'

            Thor::Shell::Basic.new.say_status 'warning', 'Could not find unison binary in $PATH. Trying to install now', :red
            Thor::Shell::Basic.new.say_status 'command', cmd1, :white
            if Thor::Shell::Basic.new.yes?('I will install unison using brew for you? (y/N)')
              system cmd1
            else
              raise('Please install it yourself using: brew install unison')
            end
          end

          unox_available
        end
      end

      def fswatch_available
        if should_run_precondition?
          if (find_executable0 'fswatch').nil?
            cmd1 = 'brew install fswatch'

            Thor::Shell::Basic.new.say_status 'warning', 'No fswatch available. Install it by "brew install fswatch Trying to install now', :red
            Thor::Shell::Basic.new.say_status 'command', cmd1, :white
            if Thor::Shell::Basic.new.yes?('I will install fswatch using brew for you? (y/N)')
              system cmd1
            else
              raise('Please install it yourself using: brew install fswatch')
            end
          end
        end

      end

      private

      def should_run_precondition?(silent = false)
        unless has_brew?
          Thor::Shell::Basic.new.say_status 'inf', 'Not running any precondition checks since you have no brew and that is unsupported. Is all up to you know.', :white unless silent
          return false
        end
        return true
      end

      def has_brew?
        return find_executable0 'brew'
      end


      def unox_available
        if should_run_precondition?
          `brew list unox`
          if $?.exitstatus > 0
            if File.exist?('/usr/local/bin/unison-fsmonitor')
              # unox installed, but not using brew, we do not allow that anymore
              Thor::Shell::Basic.new.say_status 'error', 'You installed unison-fsmonitor (unox) not using brew-method - the old legacy way. We need to fix that.', :red
              uninstall_cmd='sudo rm /usr/local/bin/unison-fsmonitor'
              Thor::Shell::Basic.new.say_status 'command', uninstall_cmd, :white

              if Thor::Shell::Basic.new.yes?('Should i uninstall the legacy /usr/local/bin/unison-fsmonitor for you ? (y/N)')
                system uninstall_cmd
              else
                Thor::Shell::Basic.new.say_status 'error', 'Uninstall /usr/local/bin/unison-fsmonitor manually please', :white
                exit 1
              end

            end
            cmd1 = 'brew tap eugenmayer/dockersync && brew install eugenmayer/dockersync/unox'

            Thor::Shell::Basic.new.say_status 'warning', 'Could not find unison-fsmonitor (unox) binary in $PATH. Trying to install now', :red
            Thor::Shell::Basic.new.say_status 'command', cmd1, :white
            if Thor::Shell::Basic.new.yes?('I will install unox through brew for you? (y/N)')
              system cmd1
            else
              raise('Please install it yourself using: brew tap eugenmayer/dockersync && brew install unox')
            end
          end
        end
      end

      def install_pip(package, test = nil)
        test ? `python -c 'import #{test}'` : `python -c 'import #{package}'`

        unless $?.success?
          Thor::Shell::Basic.new.say_status 'warning', "Could not find #{package}. Will try to install it using pip", :red
          if find_executable0('python') == '/usr/bin/python'
            Thor::Shell::Basic.new.say_status 'ok', 'You seem to use the system python, we will need sudo below'
            sudo = true
            cmd2 = "sudo easy_install pip && sudo pip install #{package}"
          else
            Thor::Shell::Basic.new.say_status 'ok', 'You seem to have a custom python, using non-sudo commands'
            sudo = false
            cmd2 = "easy_install pip && pip install #{package}"
          end
          if sudo
            question = "I will ask you for you root password to install #{package} by running (This will ask for sudo, since we use the system python)"
          else
            question = "I will now install #{package} for you by running"
          end

          Thor::Shell::Basic.new.say_status 'info', "#{question}: `#{cmd2}\n\n"
          if Thor::Shell::Basic.new.yes?('Shall I continue? (y/N)')
            system cmd2
            if $?.exitstatus > 0
              raise("Failed to install #{package}, please file an issue with the output of the error")
            end
            test ? `python -c 'import #{test}'` : `python -c 'import #{package}'`
            unless $?.success?
              raise("Somehow I could not successfully install #{package} even though I tried. Please report this issue.")
            end
          else
            raise("Please install #{package} manually, see https://github.com/EugenMayer/docker-sync/wiki/1.-Installation")
          end
        end
      end
    end
  end
end
