name "chefdk-chef"
default_version "00542096387084857772a310bcd9ea51994701e7"

license "Apache-2.0"
license_file "LICENSE"

# Grab accompanying notice file.
# So that Open4/deep_merge/diff-lcs disclaimers are present in Omnibus LICENSES tree.
license_file "NOTICE"

source git: "https://github.com/chef/chef.git"

relative_path "chef"

dependency "ruby"
dependency "rubygems"
dependency "bundler"
dependency "ohai"
dependency "libarchive" # for archive resource

build do
  env = with_standard_compiler_flags(with_embedded_path)

  # compiled ruby on windows 2k8R2 x86 is having issues compiling
  # native extensions for pry-byebug so excluding for now
  excluded_groups = %w{server docgen maintenance pry travis integration ci}
  excluded_groups << "ruby_prof" if aix?
  excluded_groups << "ruby_shadow" if aix?

  # install the whole bundle first
  bundle "install --without #{excluded_groups.join(' ')}", env: env

  # Install components that live inside Chef's git repo. For now this is just
  # 'chef-config'
  bundle "exec rake install_components", env: env

  gemspec_name = windows? ? "chef-universal-mingw32.gemspec" : "chef.gemspec"

  # This step will build native components as needed - the event log dll is
  # generated as part of this step.  This is why we need devkit.
  gem "build #{gemspec_name}", env: env

  # Don't use -n #{install_dir}/bin. Appbundler will take care of them later
  gem "install chef*.gem --no-ri --no-rdoc --verbose", env: env

  # ensure we put the gems in the right place to get picked up by the publish scripts
  delete "pkg"
  mkdir "pkg"
  copy "chef*.gem", "pkg"

  # Always deploy the powershell modules in the correct place.
  if windows?
    mkdir "#{install_dir}/modules/chef"
    copy "distro/powershell/chef/*", "#{install_dir}/modules/chef"
  end

  # Clean up
  # TODO: Move this cleanup to a more appropriate place that's common to all
  # software we ship. Lot's of other dependencies and libraries we build for
  # ChefDK create docs and man pages and those may occur after this build step.
  delete "#{install_dir}/embedded/docs"
  delete "#{install_dir}/embedded/share/man"
  delete "#{install_dir}/embedded/share/doc"
  delete "#{install_dir}/embedded/share/gtk-doc"
  delete "#{install_dir}/embedded/ssl/man"
  delete "#{install_dir}/embedded/man"
  delete "#{install_dir}/embedded/info"
end
